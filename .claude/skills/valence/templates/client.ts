// valence bridge client. Copied by /valence; owned by this app after that. Spec: contracts.md §4.
import { METHOD_SINCE, type Events, type Methods } from './bridge.g';

type Reply =
  | { id: number; ok: true; v: unknown }
  | { id: number; ok: false; e: { code: string; message: string } };
type Params<M extends keyof Methods> = Methods[M]['params'];
type Returns<M extends keyof Methods> = Methods[M]['returns'];
// Params are optional only when every field is optional, so call('data.get') without params does not compile.
type Args<M extends keyof Methods> = {} extends Params<M> ? [params?: Params<M>] : [params: Params<M>];
type Shim = { [M in keyof Methods]?: (params: Params<M>) => Promise<Returns<M>> };

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
    this.code = code;
  }
}

const pending = new Map<number, { resolve(v: unknown): void; reject(e: BridgeError): void }>();
const listeners = new Map<string, Set<(payload: never) => void>>();
let nextId = 1;
let hostBridge: number | undefined;
let shim: Shim = {};

if (typeof window !== 'undefined') {
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

/** True inside the valence host, false in a normal browser. */
export const inHost = () => typeof window !== 'undefined' && !!window.Valence;

/** Browser fallbacks, so the same web build works as the website. Unlisted methods throw E_UNSUPPORTED on the web. */
export function installShim(s: Shim) {
  shim = s;
}

// Per-launch secret the host server writes into the entry page; the host rejects messages without it (contracts §4.2).
const nonce = () => document.querySelector<HTMLMetaElement>('meta[name="valence-nonce"]')?.content ?? '';

export function call<M extends keyof Methods>(m: M, ...[params = {} as Params<M>]: Args<M>): Promise<Returns<M>> {
  if (!inHost()) {
    const fn = shim[m] as ((p: Params<M>) => Promise<Returns<M>>) | undefined;
    return fn ? fn(params) : Promise.reject(new BridgeError('E_UNSUPPORTED', `${m} is not available on the web`));
  }
  if (hostBridge !== undefined && METHOD_SINCE[m] > hostBridge) {
    return Promise.reject(new BridgeError('E_UNSUPPORTED', `${m} needs host bridge ${METHOD_SINCE[m]}, host has ${hostBridge}`));
  }
  // ponytail: no per-call timeout; a reload drops pending calls with the page. Add one if a handler can hang.
  return new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve: resolve as (v: unknown) => void, reject });
    window.Valence!.postMessage(JSON.stringify({ id, n: nonce(), m, p: params }));
  });
}

/** Call once at startup, before has(). */
export async function connect() {
  if (inHost()) hostBridge = (await call('app.info')).bridge;
}

export function has(m: keyof Methods) {
  return inHost() ? hostBridge !== undefined && METHOD_SINCE[m] <= hostBridge : m in shim;
}

export function on<E extends keyof Events>(e: E, fn: (payload: Events[E]) => void) {
  const set = listeners.get(e) ?? new Set();
  set.add(fn as (payload: never) => void);
  listeners.set(e, set);
  // void, not Set.delete's boolean: a React useEffect cleanup must return void or a destructor.
  return () => {
    set.delete(fn as (payload: never) => void);
  };
}

/** Tell the host the first meaningful paint happened. Commits a trial bundle (contracts.md §2.4). */
export const ready = () => (inHost() ? call('app.ready') : Promise.resolve());
