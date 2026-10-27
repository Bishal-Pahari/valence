/** Matches valence.plugin.json; consume calls through your app's bridge.g.ts. */
export interface HapticsMethods {
  'haptics.tap': { params: Record<string, never>; returns: void };
}
