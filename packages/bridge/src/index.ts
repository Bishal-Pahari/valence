// @getvalence/bridge — the web half of the Valence typed bridge. Spec: contracts.md §4.
//
// The runtime lives here so a fix ships once. What is app-specific — the method and event tables, the
// payload types, METHOD_SINCE — is generated into bridge.g.ts by `valence codegen`, which binds it with
// createBridge(). Nothing in this file knows an app's schema.

/** Any JSON value, including null. Mirrors the `json` type in the IDL (§4.1). */
export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

// M and E are the generated `Methods` and `Events` interfaces. They are deliberately unconstrained: a
// constraint like `Record<string, {params, returns}>` would force an index signature onto them, and that
// signature's `params: object` then widens every entry of Shim<M> back to `object`.
type Params<M, K extends keyof M> = M[K] extends { params: infer P } ? P : never;
type Returns<M, K extends keyof M> = M[K] extends { returns: infer R } ? R : never;
// Params are optional only when every field is optional, so call('data.get') without params does not compile.
type Args<M, K extends keyof M> = {} extends Params<M, K>
  ? [params?: Params<M, K>]
  : [params: Params<M, K>];

/** Browser fallbacks, so one web build serves both the website and the app (§4.3). */
export type Shim<M> = {
  [K in keyof M]?: (params: Params<M, K>) => Promise<Returns<M, K>>;
};

type Reply =
  | { id: number; ok: true; v: unknown }
  | { id: number; ok: false; e: { code: string; message: string } };

declare global {
  interface Window {
    Valence?: { postMessage(message: string): void };
    __valence?: { r(reply: Reply): void; e(name: string, payload: unknown): void };
  }
}

export class BridgeError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'BridgeError';
    this.code = code;
  }
}

/** contracts §4.2: the per-message cap, well under Android's ~1 MB process-wide Binder buffer. */
export const MAX_MESSAGE_BYTES = 262_144;

/** True inside the Valence host, false in a normal browser. */
export const inHost = (): boolean => typeof window !== 'undefined' && !!window.Valence;

/** A validated external link and its local destination (contracts §6.3). */
export interface AppLink {
  url: string;
  path: string;
}

/** Validates before passing untrusted native event data to a router. */
function checkedLink(value: unknown): AppLink {
  if (!value || typeof value !== 'object') throw new BridgeError('E_PARAMS', 'invalid link');
  const { url, path } = value as Partial<AppLink>;
  if (typeof url !== 'string' || typeof path !== 'string' ||
      new TextEncoder().encode(url).length > 8192 || !path.startsWith('/') || path.startsWith('//') ||
      /[\x00-\x20\x7f\\]/.test(path) || /%(?![0-9a-f]{2})/i.test(path)) {
    throw new BridgeError('E_PARAMS', 'invalid link destination');
  }
  let decoded: string;
  const pathname = path.split(/[?#]/, 1)[0]!;
  try { decoded = decodeURIComponent(pathname); } catch { throw new BridgeError('E_PARAMS', 'invalid link escape'); }
  if (/%2f|%5c/i.test(pathname) || /[\x00-\x20\x7f\\]/.test(decoded) ||
      decoded.split('/').some((s) => s === '.' || s === '..') || decoded === '/_host' || decoded.startsWith('/_host/')) {
    throw new BridgeError('E_DENIED', 'unsafe link destination');
  }
  return { url, path };
}

function routeLink(link: AppLink): void {
  const target = new URL(link.path, window.location.origin);
  if (target.origin !== window.location.origin) throw new BridgeError('E_DENIED', 'off-origin link');
  window.history.pushState(null, '', link.path);
  window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
}

/**
 * Subscribe after connect(), before requesting the pending cold-start link.
 * Defaults to History API routing plus popstate. Return cleanup from your app's root effect.
 * Errors go to onError (the default logs a fixed message without the link's contents).
 */
export function onLink(
  handler: (link: AppLink) => void = routeLink,
  onError: (error: unknown) => void = () => console.error('Valence link could not be routed'),
): () => void {
  return subscribeLink(handler, onError, 9);
}

function subscribeLink(
  handler: ((link: AppLink) => void) | undefined,
  onError: ((error: unknown) => void) | undefined,
  since: number | undefined,
): () => void {
  const supported = since !== undefined && (inHost() ? hostBridge !== undefined && hostBridge >= since : 'link.initial' in shim);
  if (!supported) return () => {};
  installTransport();
  let active = true;
  let live = false;
  const deliver = (value: unknown) => {
    if (!active) return;
    try { (handler ?? routeLink)(checkedLink(value)); }
    catch (error) { (onError ?? (() => console.error('Valence link could not be routed')))(error); }
  };
  const receive = (value: never) => { live = true; deliver(value); };
  const set = listeners.get('link.opened') ?? new Set();
  set.add(receive);
  listeners.set('link.opened', set);
  void rawCall('link.initial', {}, since).then((value) => {
    if (!live && value !== null) deliver(value);
  }).catch((error: unknown) => {
    if (active) (onError ?? (() => console.error('Valence initial link unavailable')))(error);
  });
  return () => { active = false; set.delete(receive); };
}

// One transport per page, shared by every createBridge() call: window.__valence is a single global, and
// the host replies to whichever handler is installed. Keeping it module-level makes a second call harmless.
const pending = new Map<number, { resolve(v: unknown): void; reject(e: BridgeError): void }>();
const listeners = new Map<string, Set<(payload: never) => void>>();
let nextId = 1;
let hostBridge: number | undefined;
let shim: Record<string, ((params: never) => Promise<unknown>) | undefined> = {};
let installed = false;

function installTransport(): void {
  if (installed || typeof window === 'undefined') return;
  installed = true;
  window.__valence = {
    r(reply) {
      const p = pending.get(reply.id);
      if (!p) return;
      pending.delete(reply.id);
      if (reply.ok) p.resolve(reply.v);
      else p.reject(new BridgeError(reply.e.code, reply.e.message));
    },
    e(name, payload) {
      for (const fn of listeners.get(name) ?? []) fn(payload as never);
    },
  };
}

// Per-launch secret the host's server writes into the entry page; the host rejects messages without it (§3).
const nonce = (): string =>
  (typeof document === 'undefined'
    ? ''
    : document.querySelector<HTMLMetaElement>('meta[name="valence-nonce"]')?.content) ?? '';

function rawCall(m: string, params: object, since: number | undefined): Promise<unknown> {
  if (!inHost()) {
    const fn = shim[m];
    return fn
      ? fn(params as never)
      : Promise.reject(new BridgeError('E_UNSUPPORTED', `${m} is not available on the web`));
  }
  if (hostBridge !== undefined && since !== undefined && since > hostBridge) {
    return Promise.reject(
      new BridgeError('E_UNSUPPORTED', `${m} needs host bridge ${since}, host has ${hostBridge}`),
    );
  }
  // ponytail: no per-call timeout; a reload drops pending calls with the page. Add one if a handler can hang.
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const msg = JSON.stringify({ id, n: nonce(), m, p: params });
    // Android routes this through Binder, whose ~1 MB transaction buffer is shared process-wide; overrunning it
    // kills the WebView with nothing either side can catch. Refuse here, where there is still a promise to
    // reject (§4.2). Bytes, not UTF-16 code units: a multi-byte string can be a third of the cap long and
    // three times it in size.
    const size = new TextEncoder().encode(msg).length;
    if (size > MAX_MESSAGE_BYTES) {
      reject(
        new BridgeError(
          'E_TOO_LARGE',
          `${m}: message is ${size} bytes, over the ${MAX_MESSAGE_BYTES} byte bridge cap. Bytes do not go through the bridge; serve them over /_host/ instead (contracts §3).`,
        ),
      );
      return;
    }
    pending.set(id, { resolve, reject });
    window.Valence!.postMessage(msg);
  });
}

/** The typed surface `valence codegen` re-exports from bridge.g.ts. */
export interface Bridge<M, E> {
  /** Subscribe to deep links after connect(). Unsupported schemas/hosts are a no-op. */
  onLink(handler?: (link: AppLink) => void, onError?: (error: unknown) => void): () => void;
  call<K extends keyof M & string>(m: K, ...args: Args<M, K>): Promise<Returns<M, K>>;
  /**
   * True when the host can serve this method, or emit this event. Call connect() first.
   *
   * **Events are gateable too.** `on()` for an event the host has never heard of subscribes happily and
   * then never fires, which is harmless for a listener and not harmless for the feature behind it — so
   * gate the feature, not the subscription. On the web `has()` is true for a method the shim implements
   * and false for every event, because no host is there to emit one.
   *
   * It gates *names*. A param added to a method that already existed has no `since` of its own, so
   * `has('data.list')` cannot tell you whether this host accepts `after`; gate that on the sibling name
   * that shipped in the same version (`has('data.count')`).
   */
  has(m: (keyof M | keyof E) & string): boolean;
  /** Subscribe to a host event. The returned unsubscribe is void, so it is a valid React effect cleanup. */
  on<K extends keyof E & string>(e: K, fn: (payload: E[K]) => void): () => void;
  /**
   * Tell the host this page is on screen. Commits a trial bundle (§2.4).
   *
   * Call it once per page load, from **every path that paints** — a first-run gate, an empty state, a
   * permission prompt and an error screen all paint without a data load finishing, and a path that stays
   * silent gets healthy code rolled back two launches later.
   */
  ready(): Promise<void>;
  /** Call once at startup, before has(). */
  connect(): Promise<void>;
  installShim(s: Shim<M>): void;
}

/**
 * Binds the generated method table to the runtime. `valence codegen` emits the one call an app needs;
 * app code imports the result from bridge.g.ts and never calls this itself.
 */
export function createBridge<M, E>(
  methodSince: { readonly [K in keyof M]: number },
  // Required, not defaulted. A default of `{}` would let an app upgrade this package without
  // regenerating and get `has(<any event>)` === false on every host, for ever and silently — while the
  // widened `has()` type is exactly what makes that call compile. Required, a stale `bridge.g.ts` fails
  // to build and names the thing to regenerate, which is the failure this whole surface exists to turn
  // silent no-ops into. Nothing but generated code calls this.
  eventSince: { readonly [K in keyof E]: number },
): Bridge<M, E> {
  installTransport();
  return {
    onLink: (handler, onError) => subscribeLink(handler, onError, (methodSince as Record<string, number>)['link.initial']),
    call: ((m: string, params: object = {}) => rawCall(m, params, methodSince[m as keyof M])) as Bridge<
      M,
      E
    >['call'],
    // Methods and events in one table, because `has()` answers one question — can this host do this
    // name — and a caller should not have to know which kind a name is to ask it. An unknown name is
    // false rather than a throw: `has()` exists to be asked about names this host may not have.
    // On the web, a method is whatever the shim implements and an event is nothing: no host, no events.
    has: (m) => {
      if (!inHost()) return m in shim;
      const since = (methodSince as Record<string, number | undefined>)[m] ??
        (eventSince as Record<string, number | undefined>)[m];
      return hostBridge !== undefined && since !== undefined && since <= hostBridge;
    },
    on(e, fn) {
      const set = listeners.get(e) ?? new Set();
      set.add(fn as (payload: never) => void);
      listeners.set(e, set);
      // void, not Set.delete's boolean: a React useEffect cleanup must return void or a destructor.
      return () => {
        set.delete(fn as (payload: never) => void);
      };
    },
    // app.ready and app.info are required of every schema (the CLI enforces it), so the names are safe here.
    ready: () => (inHost() ? (rawCall('app.ready', {}, undefined) as Promise<void>) : Promise.resolve()),
    async connect() {
      if (!inHost()) return;
      const info = (await rawCall('app.info', {}, undefined)) as { bridge: number };
      hostBridge = info.bridge;
    },
    installShim(s) {
      shim = s as typeof shim;
    },
  };
}

/** Test seam: drops the transport and every registered listener, shim and pending call. */
export function __resetForTests(): void {
  pending.clear();
  listeners.clear();
  nextId = 1;
  hostBridge = undefined;
  shim = {};
  installed = false;
  if (typeof window !== 'undefined') delete window.__valence;
}
