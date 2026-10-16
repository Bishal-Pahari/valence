# Security policy

Valence signs and verifies the code that runs inside your users' apps, so security reports are welcome and taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.** Report privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability**. That creates a private advisory that only the maintainer can see.

Include what you can:

- what an attacker could do, and what they need first (for example "control of the CDN" or "a crafted `bridge.schema.json`");
- the affected file or spec section (`contracts.md` §…);
- steps or a small proof of concept;
- the Valence version (`node valence/valence.mjs version`).

The maintainer aims to acknowledge a report within 7 days and to agree a disclosure date with you once a fix is ready. You will be credited in the advisory unless you prefer not to be.

## Supported versions

Valence is in beta. Only the latest `0.x` release gets security fixes.

## What is in scope

- Signing and verification: the canonical check order, signature handling, key handling and the keyring (`valence.mjs` and `contracts.md` §2).
- The update state machine: anything that lets a bad bundle stick, skip its trial, or push a phone below its floor (§2.4).
- The bridge trust boundary: the nonce, strict decoding, the navigation lock and the URL scheme allow-list (§3, §4, §7).
- Code generation: anything in a schema or config that can inject code into generated Dart or TypeScript.
- The wizard and CLI: writing, deleting or publishing files outside what they should touch.
- Flaws in the spec itself, even if no code implements them yet.

The Flutter host in your app is generated from the spec and then belongs to your app. Report bugs in it here if the spec or the generator caused them.

## Out of scope

- Attacks that need your signing key, or control of your machine or CI.
- Running the tools inside a repository you do not trust: its own build scripts can already run code.
- Denial of service against your OTA host or sync API.
