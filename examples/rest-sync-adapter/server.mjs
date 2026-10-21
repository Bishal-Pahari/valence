// Single-user, loopback-only REST -> Valence sync example. Node >= 22.18, no dependencies.
import { resolve } from 'node:path';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { timingSafeEqual } from 'node:crypto';

const MAX_BYTES = 1024 * 1024;
const encode = (v) => JSON.stringify(v);
const failure = (status) => Object.assign(new Error('adapter request failed'), { status });

async function jsonBody(stream) {
  let bytes = 0;
  const chunks = [];
  for await (const chunk of stream) {
    bytes += chunk.length;
    if (bytes > MAX_BYTES) throw failure(413);
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw failure(400); }
}

/** One identity, one database, one writable schema-1 bucket named items. */
export function createAdapter({ database, upstream, token, upstreamToken, fetchImpl = fetch }) {
  const base = new URL(upstream);
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password || base.search || base.hash) throw new Error('invalid upstream');
  if (typeof token !== 'string' || !token) throw new Error('ADAPTER_TOKEN is required');
  const db = new DatabaseSync(database);
  db.exec(`PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS rows (k TEXT PRIMARY KEY, v TEXT, u INTEGER NOT NULL, d INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS ops (id TEXT PRIMARY KEY, payload TEXT NOT NULL, row TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS clock (n INTEGER NOT NULL);
    INSERT INTO clock SELECT 0 WHERE NOT EXISTS (SELECT 1 FROM clock);`);
  const transaction = (fn) => {
    db.exec('BEGIN IMMEDIATE');
    try { const v = fn(); db.exec('COMMIT'); return v; }
    catch (e) { db.exec('ROLLBACK'); throw e; }
  };
  const record = (k, v, d) => {
    const old = db.prepare('SELECT v, u, d FROM rows WHERE k = ?').get(k);
    const text = d ? null : encode(v);
    if (old && old.v === text && old.d === d) return { k, v: d ? null : v, u: old.u, d };
    db.exec('UPDATE clock SET n = n + 1');
    const u = db.prepare('SELECT n FROM clock').get().n;
    db.prepare('INSERT OR REPLACE INTO rows VALUES (?, ?, ?, ?)').run(k, text, u, d);
    return { k, v: d ? null : v, u, d };
  };
  async function rest(path, init = {}) {
    const headers = { ...init.headers };
    if (upstreamToken) headers.authorization = `Bearer ${upstreamToken}`;
    const response = await fetchImpl(`${base.href.replace(/\/$/, '')}${path}`, {
      ...init, headers, redirect: 'error', signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) throw failure(502);
    return response;
  }
  async function snapshot() {
    const response = await rest('/items');
    const items = await jsonBody(response.body);
    if (!Array.isArray(items) || items.some((v) => !v || typeof v.id !== 'string' || !v.id)) throw failure(502);
    const keys = new Set(items.map((v) => v.id));
    if (keys.size !== items.length) throw failure(502);
    transaction(() => {
      for (const value of items) record(value.id, value, 0);
      for (const row of db.prepare('SELECT k FROM rows WHERE d = 0').all()) {
        if (!keys.has(row.k)) record(row.k, null, 1);
      }
    });
  }
  const expected = Buffer.from(`Bearer ${token}`);
  // Serialize the upstream read/write and the local commit, including concurrent requests.
  let tail = Promise.resolve();
  const server = createServer((req, res) => {
    const run = async () => {
      const actual = Buffer.from(req.headers.authorization ?? '');
      if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) throw failure(401);
      const url = new URL(req.url, 'http://localhost');
      if (req.method === 'GET' && url.pathname === '/rpc') return { native: true, authenticated: true };
      if (req.method === 'GET' && url.pathname === '/items') {
        const since = Number(url.searchParams.get('since') ?? 0);
        const limit = Number(url.searchParams.get('limit') ?? 500);
        if (url.searchParams.get('schema') !== '1') throw failure(404);
        if (!Number.isSafeInteger(since) || since < 0 || !Number.isSafeInteger(limit) || limit < 1 || limit > 500) throw failure(400);
        await snapshot();
        const rows = db.prepare('SELECT * FROM rows WHERE u > ? ORDER BY u LIMIT ?').all(since, limit + 1);
        const more = rows.length > limit;
        const page = rows.slice(0, limit).map((r) => ({ k: r.k, v: r.d ? null : JSON.parse(r.v), u: r.u, d: r.d }));
        return { bucket: 'items', schema: 1, rows: page, max: page.at(-1)?.u ?? since, more };
      }
      if (req.method === 'POST' && url.pathname === '/items/push') {
        const body = await jsonBody(req);
        // The host sends its whole outbox. Bound bytes in jsonBody, not operation count:
        // refusing a 201-operation batch would reject the same queued writes forever.
        if (!body || !Array.isArray(body.ops)) throw failure(400);
        const valid = body.ops.every((op) => op && typeof op.id === 'string' && op.id.length > 0 && op.id.length <= 128 &&
          typeof op.k === 'string' && op.k.length > 0 && op.k.length <= 256 && [0, 1].includes(op.d) &&
          (op.d === 1 || (op.v && typeof op.v === 'object' && !Array.isArray(op.v) && op.v.id === op.k)));
        if (!valid) throw failure(400);
        const acked = [], rows = [];
        for (const op of body.ops) {
          const payload = encode({ k: op.k, v: op.d ? null : op.v, d: op.d });
          const old = db.prepare('SELECT payload, row FROM ops WHERE id = ?').get(op.id);
          if (old && old.payload !== payload) throw failure(409);
          let row;
          if (old) {
            // The client's pull may already have advanced past a newer writer while skipping this
            // key due to its outbox. Echoing the historic receipt would strand it on stale data.
            const current = db.prepare('SELECT * FROM rows WHERE k = ?').get(op.k);
            row = { k: op.k, v: current.d ? null : JSON.parse(current.v), u: current.u, d: current.d };
          }
          else {
            // Upstream MUST honor this key across retries, including a crash before the local commit.
            await rest(`/items/${encodeURIComponent(op.k)}`, {
              method: op.d ? 'DELETE' : 'PUT',
              headers: { 'content-type': 'application/json', 'idempotency-key': op.id },
              ...(op.d ? {} : { body: encode(op.v) }),
            });
            row = transaction(() => {
              const r = record(op.k, op.v, op.d);
              db.prepare('INSERT INTO ops VALUES (?, ?, ?)').run(op.id, payload, encode(r));
              return r;
            });
          }
          acked.push(op.id); rows.push(row);
        }
        return { acked, rows };
      }
      throw failure(404);
    };
    const operation = tail.then(run);
    tail = operation.catch(() => {});
    operation.then((v) => {
      res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      res.end(encode(v));
    }, (e) => {
      res.writeHead(e.status ?? 502, { 'content-type': 'application/json' });
      res.end(encode({ error: 'adapter request failed' }));
    });
  });
  server.on('close', () => db.close());
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = createAdapter({
    database: process.env.ADAPTER_DB ?? 'adapter.db', upstream: process.env.UPSTREAM_URL,
    token: process.env.ADAPTER_TOKEN, upstreamToken: process.env.UPSTREAM_TOKEN,
  });
  server.listen(Number(process.env.PORT ?? 8787), '127.0.0.1');
}
