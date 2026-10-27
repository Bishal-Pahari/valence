// Run after building --release with the sentinel define documented in docs/r9-validation.md.
import { readFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';
import assert from 'node:assert/strict';

const bytes = readFileSync(process.argv[2]);
const sentinel = process.argv[3];
assert.ok(sentinel, 'pass the exact VALENCE_DEV_URL supplied to the release build');
let end = bytes.length - 22;
while (end >= Math.max(0, bytes.length - 65557) && bytes.readUInt32LE(end) !== 0x06054b50) end--;
assert.ok(end >= 0 && bytes.readUInt32LE(end) === 0x06054b50, 'APK ZIP directory missing');
let offset = bytes.readUInt32LE(end + 16);
let checked = 0;
while (bytes.readUInt32LE(offset) === 0x02014b50) {
  const method = bytes.readUInt16LE(offset + 10);
  const length = bytes.readUInt32LE(offset + 20);
  const nameLength = bytes.readUInt16LE(offset + 28);
  const extraLength = bytes.readUInt16LE(offset + 30);
  const commentLength = bytes.readUInt16LE(offset + 32);
  const local = bytes.readUInt32LE(offset + 42);
  const name = bytes.toString('utf8', offset + 46, offset + 46 + nameLength);
  // An APK keeps the AOT libraries at lib/<abi>/, an app bundle at base/lib/<abi>/ (and a split config
  // at <split>/lib/<abi>/). The artefact submitted to Play is the bundle, so matching only the APK
  // layout means `checked` stays 0 there — it fails closed rather than passing, but it cannot check the
  // thing you actually ship.
  if (/^(?:[^/]+\/)?lib\/[^/]+\/libapp\.so$/.test(name)) {
    const start = local + 30 + bytes.readUInt16LE(local + 26) + bytes.readUInt16LE(local + 28);
    const compressed = bytes.subarray(start, start + length);
    assert.ok(method === 0 || method === 8, 'unsupported ZIP compression');
    const data = method === 8 ? inflateRawSync(compressed) : compressed;
    for (const needle of [sentinel, 'VALENCE_DEV_URL must be an HTTP(S) origin', 'development WebSocket handshake refused']) {
      assert.equal(data.includes(Buffer.from(needle)), false, `${name} includes dev code: ${needle}`);
    }
    checked++;
  }
  offset += 46 + nameLength + extraLength + commentLength;
}
assert.ok(checked > 0, 'no release AOT libraries found (a debug APK cannot prove exclusion)');
console.log(`Release exclusion passed for ${checked} AOT libraries`);
