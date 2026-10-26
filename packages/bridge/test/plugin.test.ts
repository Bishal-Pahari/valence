import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createBridge, __resetForTests } from '../src/index.ts';
import type { HapticsMethods } from '../../valence/example/plugins/haptics/web-types/index.js';

test('plugin types use the ordinary client, capability gate and browser shim', async () => {
  __resetForTests();
  (globalThis as any).window = {};
  (globalThis as any).document = { querySelector: () => null };
  const bridge = createBridge<HapticsMethods, Record<string, never>>({ 'haptics.tap': 1 }, {});
  assert.equal(bridge.has('haptics.tap'), false);
  await assert.rejects(bridge.call('haptics.tap'), { code: 'E_UNSUPPORTED' });
  let taps = 0;
  bridge.installShim({ 'haptics.tap': async () => { taps++; } });
  assert.equal(bridge.has('haptics.tap'), true);
  await bridge.call('haptics.tap');
  assert.equal(taps, 1);
  __resetForTests();
  delete (globalThis as any).window;
  delete (globalThis as any).document;
});
