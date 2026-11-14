import assert from 'node:assert/strict';
import { test, beforeEach } from 'node:test';

import { onLink, createBridge, __resetForTests } from '../src/index.ts';

type Methods = {
  'app.info': { params: {}; returns: { bridge: number } };
  'link.initial': { params: {}; returns: { url: string; path: string } | null };
};
const table = { 'app.info': 1, 'link.initial': 9 };
const link = (path: string) => ({ url: `https://links.example.com${path}`, path });
const flush = () => new Promise<void>((resolve) => setImmediate(resolve));

beforeEach(() => { __resetForTests(); delete (globalThis as any).window; });

function host(version = 9) {
  const sent: any[] = [];
  (globalThis as any).window = { Valence: { postMessage: (s: string) => sent.push(JSON.parse(s)) } };
  const b = createBridge<Methods, {}>(table, {});
  const connect = b.connect();
  window.__valence!.r({ id: sent[0].id, ok: true, v: { bridge: version } });
  return { b, sent, connect };
}

test('subscribes before initial; live event supersedes delayed launch reply and repeats are kept', async () => {
  const { b, sent, connect } = host(); await connect;
  const paths: string[] = [];
  const off = b.onLink((l) => paths.push(l.path));
  window.__valence!.e('link.opened', link('/warm?q=1#x'));
  window.__valence!.r({ id: sent[1].id, ok: true, v: link('/cold') });
  await flush();
  window.__valence!.e('link.opened', link('/warm?q=1#x'));
  assert.deepEqual(paths, ['/warm?q=1#x', '/warm?q=1#x']);
  off(); window.__valence!.e('link.opened', link('/after'));
  assert.equal(paths.length, 2);
});

test('a handler is told which arrival each link was, so one arbiter can order both sources', async () => {
  // K F-79: the wrapper already distinguishes the launch mailbox from a live event -- it is what makes
  // a live event supersede a pending initial reply -- and without passing that on, §6.3's "latest event
  // wins across sources" is a rule a page cannot write through the supported API.
  const { b, sent, connect } = host(); await connect;
  const seen: Array<[string, boolean]> = [];
  b.onLink((l) => seen.push([l.path, l.initial]));
  window.__valence!.r({ id: sent[1].id, ok: true, v: link('/cold') });
  await flush();
  window.__valence!.e('link.opened', link('/warm'));
  assert.deepEqual(seen, [['/cold', true], ['/warm', false]]);

  // And the other order: a live event first means the launch reply is never delivered at all, so a page
  // that drops every later initial is consistent with what the wrapper already does.
  __resetForTests();
  const second = host(); await second.connect;
  const later: Array<[string, boolean]> = [];
  second.b.onLink((l) => later.push([l.path, l.initial]));
  window.__valence!.e('link.opened', link('/live'));
  window.__valence!.r({ id: second.sent[1].id, ok: true, v: link('/launch') });
  await flush();
  assert.deepEqual(later, [['/live', false]]);
});

test('unsubscribe suppresses delayed initial navigation; old host sends no link call', async () => {
  const { b, sent, connect } = host(); await connect;
  const paths: string[] = [];
  const off = b.onLink((l) => paths.push(l.path)); off();
  window.__valence!.r({ id: sent[1].id, ok: true, v: link('/cold') });
  await flush(); assert.deepEqual(paths, []);
  __resetForTests();
  const old = host(8); await old.connect;
  old.b.onLink(); assert.equal(old.sent.length, 1);
});

test('default router preserves origin and query/hash; malicious paths and malformed events are refused', async () => {
  const { b, sent, connect } = host(); await connect;
  const routed: string[] = [], errors: unknown[] = [], events: string[] = [];
  Object.assign(window, {
    location: { origin: 'http://127.0.0.1:12345' },
    history: { pushState: (_: unknown, __: unknown, path: string) => routed.push(path) },
    dispatchEvent: (e: Event) => { events.push(e.type); return true; },
  });
  (globalThis as any).PopStateEvent = class { type: string; constructor(type: string) { this.type = type; } };
  b.onLink(undefined, (e) => errors.push(e));
  window.__valence!.r({ id: sent[1].id, ok: true, v: link('/shelf?q=1#note') });
  await flush();
  for (const value of [null, {}, link('//evil.com'), link('/\\evil.com'), link('/%2f%2fevil.com'),
    link('/a/../_host/data'), link('/%2e%2e/x'), link('/_host/x'), link('/%5fhost/x'), link('/%00'), link('/%GG')]) {
    window.__valence!.e('link.opened', value);
  }
  assert.deepEqual(routed, ['/shelf?q=1#note']); assert.deepEqual(events, ['popstate']); assert.equal(errors.length, 11);
});

test('plain browser shim can provide an initial route; missing support is inert', async () => {
  (globalThis as any).window = {};
  const b = createBridge<Methods, {}>(table, {});
  const paths: string[] = [];
  b.onLink((l) => paths.push(l.path));
  b.installShim({ 'link.initial': async () => link('/web') });
  b.onLink((l) => paths.push(l.path)); await flush();
  assert.deepEqual(paths, ['/web']);
});

test('package onLink uses schema 9 and remains inert on schema 8 hosts', async () => {
  const old = host(8); await old.connect;
  onLink(() => {}); assert.equal(old.sent.length, 1);
  __resetForTests();
  const current = host(9); await current.connect;
  const paths: string[] = [];
  const off = onLink((l) => paths.push(l.path));
  assert.equal(current.sent[1].m, 'link.initial');
  window.__valence!.r({ id: current.sent[1].id, ok: true, v: link('/current') });
  await flush(); assert.deepEqual(paths, ['/current']); off();
});
