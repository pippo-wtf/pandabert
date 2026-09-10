# Open thread — Pulse 0.1.4

Every task card and the details sheet now have an **Open thread** button. Task details remain available separately. Navigation does not mark work reviewed or submit a prompt.

## Routing evidence

Verified against the installed macOS applications on 2026-09-10:

- Codex bundle `com.openai.codex`, version `26.903.71938`, installed as `ChatGPT.app`: the registered `codex` URL handler accepts `codex://threads/<thread-id>` as a local-conversation navigation route.
- Claude bundle `com.anthropic.claudefordesktop`, version `1.49585.0`: the registered `claude` handler accepts existing conversation paths under `claude://claude.ai/epitaxy/<desktop-session-id>` and server conversation paths under `claude://claude.ai/code/<server-session-id>`.
- Claude's session store normalizes `cse_` bridge IDs to the server's `session_` form. The app's newer `claude://code/...` host was observed to be feature-gated off in the installed build, so Pulse uses the existing `claude.ai` conversation handler.

These were checked in the installed apps' Info.plist and packaged navigation/session-store code. No app files or provider settings were changed. No third-party app code is included in Pulse.

## Identity and limits

Codex uses the recorded native UUID. Claude requires an explicit local mapping read from its session metadata, using the CLI session ID rather than guessing that it equals the desktop ID. The mapping is loaded again on click so a cached or pinned task cannot open a removed mapping. Ambiguous mappings are discarded. Bridge IDs alone never enable navigation: a syntactically valid bridge ID does not prove that its conversation exists in the desktop app. Remote Claude navigation is disabled as well.

Only validated identifiers enter the fixed URL templates. No prompt, command, filesystem path or arbitrary query string is forwarded. The matching app bundle is selected explicitly; missing-app errors are surfaced. Sessions lacking a desktop connection have a disabled button and an explanation in Details.

The destination app must be signed in to an account with access to the thread. Pulse cannot verify that access through the operating system's URL-opening acknowledgement. A local metadata record establishes identity, not current account authorization; the destination app still owns that access check. Remote Codex routing is unavailable until Pulse machine identities are mapped to Codex's own connected hosts. Unlinked Claude terminal sessions are not imported or resumed automatically.

Optional identity fields preserve decoding of existing Pulse snapshots and pinned-task caches. The collector protocol version remains 1; old consumers ignore these additional JSON fields.

## Validation

The full suite passes: **21 tests, 0 failures**. Navigation coverage includes exact URLs, local/remote boundaries, malformed-ID rejection, bridge-only rejection, terminal non-import behavior, old snapshot compatibility, CLI-to-desktop mapping, deleted/changed mappings at click time and ambiguous metadata.

The release app and embedded collector were rebuilt and locally signature-verified. Live navigation results are recorded in `VALIDATION.md`.
