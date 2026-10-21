import { test } from 'node:test';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtempSync, rmSync } from 'node:fs';

import { createAdapter } from './server.mjs';

const listen = async (server) => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return `http://127.0.0.1:${server.address().port}`;
};
const close = (server) => new Promise((r) => server.close(r));

test('REST snapshots, 600-row paging, tombstones and durable idempotent push', async (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'valence-adapter-'));

  const items = new Map(Array.from({ length: 600 }, (_, n) => [`k${n}`, { id: `k${n}`, count: n }]));
  let writes = 0;
  const upstream = createServer(async (req, res) => {
    assert.equal(req.headers.authorization, 'Bearer upstream-secret');
    if (req.method === 'GET') {
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify([...items.values()]));
    } else {
      writes++;
      assert.ok(req.headers['idempotency-key']);
      const k = decodeURIComponent(req.url.slice('/items/'.length));
      if (req.method === 'DELETE') items.delete(k);
      else {
        const chunks = []; for await (const chunk of req) chunks.push(chunk);
        items.set(k, JSON.parse(Buffer.concat(chunks)));
      }
      res.writeHead(204); res.end();
    }
  });
  const upstreamUrl = await listen(upstream);

  const options = { database: join(dir, 'state.db'), upstream: upstreamUrl, token: 'app-secret', upstreamToken: 'upstream-secret' };
  let adapter = createAdapter(options);
  let base = await listen(adapter);
  t.after(async () => {
    adapter.closeAllConnections(); upstream.closeAllConnections();
    await close(adapter); await close(upstream);
    assert.ok(dir.startsWith(join(tmpdir(), 'valence-adapter-')));
    rmSync(dir, { recursive: true, force: true });
  });
  const call = async (path, body) => {
    const res = await fetch(base + path, { headers: { authorization: 'Bearer app-secret', 'content-type': 'application/json' },
      ...(body ? { method: 'POST', body: JSON.stringify(body) } : {}) });
    return { status: res.status, body: await res.json() };
  };
  assert.equal((await fetch(`${base}/items?schema=1`)).status, 401);
  assert.equal((await call('/items?schema=2')).status, 404);
  const page1 = (await call('/items?schema=1&limit=500')).body;
  assert.equal(page1.rows.length, 500); assert.equal(page1.more, true);
  assert.equal(page1.max, page1.rows.at(-1).u);
  const page2 = (await call(`/items?schema=1&since=${page1.max}`)).body;
  assert.equal(page2.rows.length, 100); assert.equal(page2.more, false);
  const head = page2.max;
  assert.equal((await call(`/items?schema=1&since=${head}`)).body.rows.length, 0);
  items.delete('k0');
  const tombstone = (await call(`/items?schema=1&since=${head}`)).body.rows;
  assert.deepEqual(tombstone.map((r) => [r.k, r.v, r.d]), [['k0', null, 1]]);

  const op = { id: 'op-1', k: 'k1', v: { id: 'k1', count: 900 }, d: 0 };
  const first = await call('/items/push', { ops: [op] });
  assert.equal(first.status, 200); assert.deepEqual(first.body.acked, ['op-1']);
  assert.equal(writes, 1);
  await close(adapter);
  adapter = createAdapter(options); base = await listen(adapter);
  assert.deepEqual((await call('/items/push', { ops: [op] })).body, first.body);
  assert.equal(writes, 1, 'a retry after process restart must not write upstream again');
  items.set('k1', { id: 'k1', count: 901 });
  await call('/items?schema=1');
  const retried = await call('/items/push', { ops: [op] });
  assert.equal(retried.body.rows[0].v.count, 901, 'lost reply retry must echo the current winning value');
  assert.ok(retried.body.rows[0].u > first.body.rows[0].u);
  assert.equal(writes, 1);
  assert.equal((await call('/items/push', { ops: [{ ...op, v: { id: 'k1', count: 1 } }] })).status, 409);
  const deletion = await call('/items/push', { ops: [{ id: 'op-2', k: 'k1', v: null, d: 1 }] });
  assert.equal(deletion.body.rows[0].d, 1); assert.equal(items.has('k1'), false);
  assert.equal((await call('/items/push', { ops: [{ ...op, id: 'op-3', v: { id: 'different' } }] })).status, 400);
  const backlog = Array.from({ length: 601 }, (_, n) => ({
    id: `backlog-${n}`, k: `new-${n}`, v: { id: `new-${n}`, count: n }, d: 0,
  }));
  const drained = await call('/items/push', { ops: backlog });
  assert.equal(drained.status, 200);
  assert.deepEqual(drained.body.acked, backlog.map((v) => v.id));
  assert.equal(writes, 603, 'all 601 offline operations reach the REST API');
  assert.equal((await call('/items/push', { ops: backlog })).status, 200);
  assert.equal(writes, 603, 'retrying a large backlog must not repeat writes');
});
