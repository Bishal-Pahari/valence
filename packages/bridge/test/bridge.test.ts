// Tests for the §4.2 wire protocol and the §4.3 client surface. Run: node --test test/*.test.ts
import {
  createBridge,
  BridgeError,
  MAX_MESSAGE_BYTES,
  inHost,
  __resetForTests,
} from '../src/index.ts';
import assert from 'node:assert/strict';
import { test, beforeEach } from 'node:test';

interface Methods {
  'app.ready': { params: Record<string, never>; returns: void };
  'app.info': { params: Record<string, never>; returns: { bridge: number } };
  'data.get': { params: { bucket: string; key: string }; returns: unknown };
  'prefs.set': { params: { key: string; value?: string | null }; returns: void };
  'media.pick': { params: Record<string, never>; returns: string | null };
}

interface Events {
  'sync.changed': { buckets: string[] };
  'app.resumed': Record<string, never>;
}

const SINCE = {
  'app.ready': 1,
  'app.info': 1,
  'data.get': 1,
  'prefs.set': 1,
  'media.pick': 4,
} as const;

type Sent = { id: number; n: string; m: string; p: unknown };

/** Mocks the webview_flutter JavaScriptChannel and the entry page's nonce meta tag. */
function host(nonce = 'nonce-abc'): { sent: Sent[] } {
  const sent: Sent[] = [];
  (globalThis as any).window = {
    Valence: { postMessage: (s: string) => sent.push(JSON.parse(s) as Sent) },
  };
  (globalThis as any).document = { querySelector: () => (nonce === '' ? null : { content: nonce }) };
  return { sent };
}

/** Mocks a plain browser: no window.Valence, so calls route to the shim. */
function browser(): void {
  (globalThis as any).window = {};
  (globalThis as any).document = { querySelector: () => null };
}

const reply = (r: unknown) => (globalThis as any).window.__valence.r(r);
const emit = (name: string, payload: unknown) => (globalThis as any).window.__valence.e(name, payload);
const EVENT_SINCE = {
  'sync.changed': 1,
  'app.resumed': 4,
} as const;

const bridge = () => createBridge<Methods, Events>(SINCE, EVENT_SINCE);

beforeEach(() => {
  __resetForTests();
  delete (globalThis as any).window;
  delete (globalThis as any).document;
});

test('inHost is false in a plain browser and true under the host channel', () => {
  browser();
  assert.equal(inHost(), false);
  host();
  assert.equal(inHost(), true);
});

test('call sends the nonce from the entry page and resolves the reply value', async () => {
  const { sent } = host();
  const v = bridge();
  const p = v.call('data.get', { bucket: 'plants', key: 'fern' });
  assert.equal(sent.length, 1);
  assert.equal(sent[0]!.n, 'nonce-abc');
  assert.equal(sent[0]!.m, 'data.get');
  assert.deepEqual(sent[0]!.p, { bucket: 'plants', key: 'fern' });
  reply({ id: sent[0]!.id, ok: true, v: { name: 'Fern' } });
  assert.deepEqual(await p, { name: 'Fern' });
});

test('an error reply rejects with a BridgeError carrying the code', async () => {
  const { sent } = host();
  const v = bridge();
  const p = v.call('data.get', { bucket: 'x', key: 'y' });
  reply({ id: sent[0]!.id, ok: false, e: { code: 'E_DENIED', message: 'bad nonce' } });
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof BridgeError);
    assert.equal(e.code, 'E_DENIED');
    assert.equal(e.message, 'bad nonce');
    return true;
  });
});

test('a missing nonce meta tag still sends a message, and the host is what denies it', async () => {
  const { sent } = host('');
  const v = bridge();
  const p = v.call('data.get', { bucket: 'x', key: 'y' });
  assert.equal(sent[0]!.n, '');
  reply({ id: sent[0]!.id, ok: false, e: { code: 'E_DENIED', message: 'bad nonce' } });
  await assert.rejects(p, BridgeError);
});

test('a reply for an unknown id is ignored rather than throwing', () => {
  host();
  bridge();
  assert.doesNotThrow(() => reply({ id: 9999, ok: true, v: null }));
});

test('an over-cap message is refused with E_TOO_LARGE before postMessage', async () => {
  const { sent } = host();
  const v = bridge();
  const p = v.call('prefs.set', { key: 'note', value: 'a'.repeat(MAX_MESSAGE_BYTES + 1) });
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof BridgeError);
    assert.equal(e.code, 'E_TOO_LARGE');
    return true;
  });
  assert.equal(sent.length, 0, 'nothing may reach Binder');
});

test('the cap is measured in UTF-8 bytes, not UTF-16 code units', async () => {
  const { sent } = host();
  const v = bridge();
  // One Japanese character is 1 UTF-16 code unit and 3 UTF-8 bytes: under the cap by length, over it by size.
  const value = 'あ'.repeat(100_000);
  assert.ok(value.length < MAX_MESSAGE_BYTES, 'under the cap as a JS string length');
  assert.ok(new TextEncoder().encode(value).length > MAX_MESSAGE_BYTES, 'over the cap in bytes');
  await assert.rejects(v.call('prefs.set', { key: 'note', value }), (e: unknown) => {
    assert.ok(e instanceof BridgeError);
    assert.equal(e.code, 'E_TOO_LARGE');
    return true;
  });
  assert.equal(sent.length, 0);
});

test('a message just under the cap is sent', async () => {
  const { sent } = host();
  const v = bridge();
  const p = v.call('prefs.set', { key: 'note', value: 'a'.repeat(MAX_MESSAGE_BYTES - 200) });
  assert.equal(sent.length, 1);
  reply({ id: sent[0]!.id, ok: true, v: null });
  await p;
});

test('connect reads the host bridge version and has() gates newer methods', async () => {
  const { sent } = host();
  const v = bridge();
  assert.equal(v.has('data.get'), false, 'has() is false before connect()');
  const c = v.connect();
  assert.equal(sent[0]!.m, 'app.info');
  reply({ id: sent[0]!.id, ok: true, v: { bridge: 3 } });
  await c;
  assert.equal(v.has('data.get'), true);
  assert.equal(v.has('media.pick'), false, 'since 4 on a bridge-3 host');
  await assert.rejects(v.call('media.pick'), (e: unknown) => {
    assert.ok(e instanceof BridgeError);
    assert.equal(e.code, 'E_UNSUPPORTED');
    return true;
  });
});

test('has() gates events as well as methods, so a feature behind one can be gated', async () => {
  // `on()` for an event the host never emits subscribes and then silently never fires. That is fine for
  // the listener and not fine for the feature behind it — a page writing a home-screen widget on the way
  // out needs to know the host cannot tell it when that is, so it can keep doing something else.
  const { sent } = host();
  const v = bridge();
  assert.equal(v.has('sync.changed'), false, 'false before connect(), like a method');
  const c = v.connect();
  reply({ id: sent[0]!.id, ok: true, v: { bridge: 3 } });
  await c;
  assert.equal(v.has('sync.changed'), true);
  assert.equal(v.has('app.resumed'), false, 'since 4 on a bridge-3 host');
  // An unknown name is false, not a throw: has() is the thing you ask about names you may not have.
  assert.equal(v.has('nope.nothing' as 'sync.changed'), false);
});

test('on the web has() is false for every event, because no host is there to emit one', async () => {
  browser();
  const v = bridge();
  v.installShim({ 'data.get': async () => null });
  await v.connect();
  assert.equal(v.has('data.get'), true, 'the shim implements it');
  assert.equal(v.has('sync.changed'), false);
});

test('a method at exactly the host bridge version is allowed', async () => {
  const { sent } = host();
  const v = bridge();
  const c = v.connect();
  reply({ id: sent[0]!.id, ok: true, v: { bridge: 4 } });
  await c;
  assert.equal(v.has('media.pick'), true);
  const p = v.call('media.pick');
  reply({ id: sent[1]!.id, ok: true, v: null });
  assert.equal(await p, null);
});

test('on() delivers the payload and its unsubscribe returns void (a valid React cleanup)', () => {
  host();
  const v = bridge();
  const seen: string[][] = [];
  const off = v.on('sync.changed', (p) => seen.push(p.buckets));
  emit('sync.changed', { buckets: ['plants'] });
  assert.deepEqual(seen, [['plants']]);
  assert.equal(off(), undefined, 'a useEffect cleanup must return void, not a boolean');
  emit('sync.changed', { buckets: ['shelf'] });
  assert.deepEqual(seen, [['plants']], 'no delivery after unsubscribe');
});

test('two listeners on one event both fire, and unsubscribing one keeps the other', () => {
  host();
  const v = bridge();
  let a = 0;
  let b = 0;
  const offA = v.on('app.resumed', () => a++);
  v.on('app.resumed', () => b++);
  emit('app.resumed', {});
  offA();
  emit('app.resumed', {});
  assert.equal(a, 1);
  assert.equal(b, 2);
});

test('an event with no listeners is dropped quietly', () => {
  host();
  bridge();
  assert.doesNotThrow(() => emit('sync.changed', { buckets: [] }));
});

test('on the web, call routes to the shim and has() reports what the shim implements', async () => {
  browser();
  const v = bridge();
  v.installShim({
    'data.get': async ({ bucket, key }) => `${bucket}/${key}`,
    'prefs.set': async () => undefined,
  });
  assert.equal(v.has('data.get'), true);
  assert.equal(v.has('media.pick'), false);
  assert.equal(await v.call('data.get', { bucket: 'plants', key: 'fern' }), 'plants/fern');
});

test('on the web, an unshimmed method rejects with E_UNSUPPORTED', async () => {
  browser();
  const v = bridge();
  v.installShim({});
  await assert.rejects(v.call('media.pick'), (e: unknown) => {
    assert.ok(e instanceof BridgeError);
    assert.equal(e.code, 'E_UNSUPPORTED');
    return true;
  });
});

test('ready() is a no-op on the web and calls app.ready in the host', async () => {
  browser();
  assert.equal(await bridge().ready(), undefined);

  __resetForTests();
  const { sent } = host();
  const v = bridge();
  const p = v.ready();
  assert.equal(sent[0]!.m, 'app.ready');
  reply({ id: sent[0]!.id, ok: true, v: null });
  await p;
});

test('connect() is a no-op on the web, so has() keeps reporting the shim', async () => {
  browser();
  const v = bridge();
  v.installShim({ 'data.get': async () => null });
  await v.connect();
  assert.equal(v.has('data.get'), true);
});

test('ids increase, so concurrent calls resolve to their own replies', async () => {
  const { sent } = host();
  const v = bridge();
  const a = v.call('data.get', { bucket: 'b', key: 'a' });
  const b = v.call('data.get', { bucket: 'b', key: 'b' });
  assert.notEqual(sent[0]!.id, sent[1]!.id);
  reply({ id: sent[1]!.id, ok: true, v: 'second' });
  reply({ id: sent[0]!.id, ok: true, v: 'first' });
  assert.deepEqual(await Promise.all([a, b]), ['first', 'second']);
});
