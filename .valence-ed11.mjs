import { readFileSync, writeFileSync } from 'node:fs';

const C = '.claude/skills/valence/references/contracts.md';
const B = '.claude/agents/valence-builder.md';
const R = '.claude/agents/valence-reviewer.md';
const S = '.claude/skills/valence/SKILL.md';
const W = 'bin/valence.mjs';

const edits = [
  // 5.1: "one instance both entry points use" is impossible across isolates. Say what actually works.
  [C,
   '- **Never close the database.** sqflite keys open databases by path inside the platform plugin, not per isolate, so a `close()` in a `workmanager` isolate or in a widget\'s `dispose()` invalidates the handle the UI isolate is holding and the next bridge call fails with `database_closed`. Open it once, keep one store instance both entry points use, and let the process own it (§5.6).',
   `- **Never close the database.** sqflite keys open databases **by path inside the platform plugin**, not per isolate, so a \`close()\` in a \`workmanager\` isolate or in a widget's \`dispose()\` invalidates the handle the UI isolate is holding and the next bridge call fails with \`database_closed\`.
  - A Dart object can't cross an isolate boundary, so "share the store instance" is not the rule. The rule is: **each isolate calls \`openDatabase\` on the same path** and gets the same plugin-side connection back, and **no isolate ever calls \`close()\`.** Keep one store object per isolate, lazily opened.
  - A background isolate must call \`DartPluginRegistrant.ensureInitialized()\` before its first store call, or the plugin isn't registered in that isolate at all. That is the other first-run-on-device failure in this code path.
- **Check that WAL took.** \`rawQuery('PRAGMA journal_mode = WAL')\` returns the mode that is now in effect; a filesystem that can't do WAL answers \`delete\` and you lose the concurrency the rest of §5 assumes. Log or assert the returned value rather than discarding it.`],

  [C,
   '- **The background isolate shares the UI\'s database handle.** sqflite registers open databases by path in the platform plugin, so both entry points must go through one store instance and neither may close it (§5.1). The lease below serialises *syncs*; it says nothing about database lifetimes.',
   '- **The background isolate shares the UI\'s database connection.** sqflite registers open databases by path in the platform plugin, so each isolate opens the same path, gets the same connection, and neither may close it; a background isolate also needs `DartPluginRegistrant.ensureInitialized()` first (§5.1). The lease below serialises *syncs*; it says nothing about database lifetimes. Because the connection is shared, keep pull pages small (§5.3 caps them at 500) so a long background transaction doesn\'t queue the UI\'s reads behind it.'],

  [B,
   '  - WAL plus `busy_timeout = 5000`',
   '  - WAL plus `busy_timeout = 5000`, both through `rawQuery` in `onConfigure` (`execute` throws on Android and the ffi test factory hides it), the returned `journal_mode` checked, never `close()`, and `DartPluginRegistrant.ensureInitialized()` in the background entry point (§5.1)'],

  [R,
   '- WAL plus `busy_timeout` are set. The sync lease prevents concurrent syncs, is renewed per page, and treats a future timestamp as expired. The SQLite file is never in a shared App Group container.',
   '- WAL plus `busy_timeout` are set **through `rawQuery`, not `execute`** (§5.1: Android rejects row-returning pragmas via `execSQL`, and `sqflite_common_ffi` accepts them, so the unit suite cannot show this). Nothing calls `close()` on the database — a `close()` in a background isolate breaks the UI isolate, so it is HIGH. The sync lease prevents concurrent syncs, is renewed per page, and treats a future timestamp as expired. The SQLite file is never in a shared App Group container.'],

  // SKILL.md: a documented order for an agent that cannot spawn subagents.
  [S,
   '### Phase 7: Hand-off',
   `### Degraded mode: no subagents

Phases 1, 4 and 6 spawn agents. If your harness can't (headless, or subagents disabled), don't stop — do the work in the main loop in this order, and **say in the hand-off which steps ran degraded**:

1. **Instead of Phase 1,** read §Stack baseline below and check the dates. Note in \`.valence/stack-check.md\` that no scout ran and that the baseline is unverified for this run. Then be conservative: pin the versions the baseline names rather than resolving \`latest\`, and treat a build failure in a listed package as drift to investigate, not as your own bug.
2. **Instead of Phase 4,** write the host first and the web side second, in the file order §Phase 4 lists them. Read \`references/contracts.md\` in full before the first file. Run \`dart analyze --fatal-infos\` after each file rather than at the end, so an error is attributable.
3. **Phase 5 is unchanged** and is now your only safety net, so run every step and don't skip the device step silently.
4. **Instead of Phase 6,** review in a **separate pass with fresh eyes**: re-read \`references/contracts.md\` §2.3, §2.4, §3, §5.1 and §7, then the code you wrote, and work the \`valence-reviewer\` checklist (\`.claude/agents/valence-reviewer.md\`) as a list, writing down the evidence for each item. **Self-review is weaker than independent review and the hand-off must say so,** with a recommendation to run \`/valence doctor\` from a fresh session before the first store submission. Never report a self-review as an independent one.

### Phase 7: Hand-off`],

  // The wizard tells people why /valence is unknown in the session that just installed it.
  [W,
   `      console.log(\`  Install Claude Code (https://code.claude.com/docs), then run in this folder:\\n\\n    \${bold(command)}\\n\`);
      return;
    }
    // claude is interactive: never start it without a terminal (CI, pipes).
    if (!o.launch || !interactive() || /^n/i.test(await ask('Launch Claude Code now? (Y/n)', 'Y'))) {
      console.log(\`  When you're ready, run in this folder:\\n\\n    \${bold(command)}\\n\`);
      return;
    }`,
   `      console.log(\`  Install Claude Code (https://code.claude.com/docs), then run in this folder:\\n\\n    \${bold(command)}\\n\${freshSession}\`);
      return;
    }
    // claude is interactive: never start it without a terminal (CI, pipes).
    if (!o.launch || !interactive() || /^n/i.test(await ask('Launch Claude Code now? (Y/n)', 'Y'))) {
      console.log(\`  When you're ready, run in this folder:\\n\\n    \${bold(command)}\\n\${freshSession}\`);
      return;
    }`],

  // The skill was installed during this run, so it is not registered in a session that is already open.
  [W,
   `    const command = 'claude "/valence init"';`,
   `    const command = 'claude "/valence init"';
    // A skill installed mid-session is not registered in that session, so /valence comes back unknown until a restart.
    const freshSession =
      \`  \${dim('That starts a new session, which matters: the skill was installed during this run, so /valence is not')}\\n\` +
      \`  \${dim('registered in a session that is already open. Without Claude Code the host is yours to write against')}\\n\` +
      \`  \${dim('the spec: https://getvalence.pages.dev/docs/reference/spec/')}\\n\`;`],
];

for (const [f, from, to] of edits) {
  const s = readFileSync(f, 'utf8');
  if (s.split(from).length !== 2) throw new Error(`no unique match in ${f}: ${from.slice(0, 55)}`);
  writeFileSync(f, s.replace(from, to));
}
console.log('ok');
