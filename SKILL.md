---
name: squirrel-input-method-architecture
description: Understand and modify the Squirrel macOS input method frontend. Use this when working on input handling, librime sessions, candidate UI, configuration, lifecycle, installer commands, or backend/frontend coordination in this repository.
---

# Squirrel Input Method Architecture Skill

Use this skill when making changes to Squirrel, a macOS InputMethodKit frontend for librime. Squirrel is an input method, so correctness depends on event ordering, session lifetime, marked text behavior, candidate window geometry, and clean handoff between the macOS text client and librime.

## Repository Map

The Xcode project is organized around one app target, `Squirrel.app`, plus bundled resources and librime plugins.

- `Squirrel/Sources/Main.swift`: process entry point, command-line maintenance commands, IMK server creation, app setup, and global librime startup.
- `Squirrel/Sources/SquirrelApplicationDelegate.swift`: app-wide state. Owns the candidate panel, global `SquirrelConfig`, status item, Sparkle update integration, distributed notifications, and librime setup/finalization.
- `Squirrel/Sources/SquirrelInputController.swift`: the main InputMethodKit controller. Owns one active librime session per controller instance, receives key events, translates macOS events to Rime key events, commits text, updates marked text, and drives the candidate panel.
- `Squirrel/Sources/MacOSKeyCodes.swift`: maps AppKit/Carbon key codes and modifier flags to librime/X11 key symbols and masks.
- `Squirrel/Sources/SquirrelConfig.swift`: thin typed wrapper over `RimeConfig`, with base config/schema fallback and cached option reads.
- `Squirrel/Sources/SquirrelTheme.swift`: converts Rime/Squirrel style configuration into fonts, colors, layout flags, candidate formatting, and drawing attributes.
- `Squirrel/Sources/SquirrelPanel.swift`: nonactivating candidate/status panel. Builds attributed candidate text, positions the panel near the text cursor, handles paging/candidate mouse events, and delegates selection actions back to the input controller.
- `Squirrel/Sources/SquirrelView.swift`: custom AppKit drawing surface for candidate/preedit backgrounds, highlights, paging affordances, vertical text, and hit testing.
- `Squirrel/Sources/ReservedProperty.swift`: reserved librime plugin property protocol for frontend UI hints such as comment highlighting and UI refresh.
- `Squirrel/Sources/BridgingFunctions.swift`: Swift helpers for C bridge structs, persistent C strings, optional assignment, and geometry utilities.
- `Squirrel/Sources/InputSource.swift`: Text Input Source registration, enable/disable/select helpers, and current input source lookup.
- `Squirrel/Resources/Info.plist`: InputMethodKit registration metadata, input modes (`Hans`, `Hant`), IMK controller class names, connection name, Sparkle metadata, and input-source properties.
- `Squirrel/Resources/Squirrel.entitlements`: disables App Sandbox, enables network client access, and disables library validation for bundled dylibs/frameworks.
- `Squirrel/SharedSupport`: bundled Rime data, default schemas, OpenCC data, and `squirrel.yaml`.
- `Squirrel/librime-*.dylib`, `Squirrel/Frameworks/Linked Frameworks/librime.1.dylib`: backend libraries and plugins used by the frontend.

## Process Startup

`SquirrelApp.main()` is the only entry point.

1. It first checks command-line arguments and exits early for maintenance commands:
   - `--quit`, `--reload`, `--sync`
   - `--install` / `--register-input-source`
   - `--enable-input-source`, `--disable-input-source`, `--select-input-source`
   - `--build`
   - `--ascii`, `--nascii`, `--getascii`
2. If no maintenance command is handled, it creates an `IMKServer` using `InputMethodConnectionName` from `Info.plist`.
3. It creates `NSApplication.shared`, assigns `SquirrelApplicationDelegate`, sets accessory activation policy, and changes the current directory to `Bundle.main.sharedSupportPath`. This is important because OpenCC/librime configuration may use relative dictionary paths.
4. It runs a quick problematic-launch detector to avoid repeated crash/freeze loops from bad configuration.
5. Normal startup calls:
   - `setupRime()`
   - `startRime(fullCheck: false)`
   - `loadSettings()`
   - `app.run()`
6. On app-run return, it calls `rimeAPI.finalize()`.

## Global Librime Initialization

`SquirrelApplicationDelegate` owns global librime setup.

- `setupRime()` creates the user data directory (`~/Library/Rime`) and temporary log directory, sets `RIME_LOG_DIR`, installs librime's notification handler, fills `RimeTraits`, and calls `rimeAPI.setup(&traits)`.
- Important trait paths and identity fields:
  - `shared_data_dir`: app bundle shared support path.
  - `user_data_dir`: `~/Library/Rime`.
  - `log_dir`: temporary `rime.squirrel` directory.
  - distribution code/name/version and `app_name = rime.squirrel`.
- `startRime(fullCheck:)` calls `rimeAPI.initialize(nil)`, then `start_maintenance(fullCheck)`. On successful maintenance it deploys `squirrel.yaml` with the `config_version` marker.
- `loadSettings()` opens base `squirrel` config, refreshes notification/status-icon settings, and loads light/dark panel themes.
- `loadSettings(for schemaID:)` opens the active schema config and, when it has a `style` section, overlays schema-specific panel style. Otherwise it falls back to base config.
- `shutdownRime()` closes config and calls `rimeAPI.finalize()`.
- `applicationShouldTerminate(_:)` calls `cleanup_all_sessions()` before termination.

Do not initialize/finalize librime from individual input controllers. Controllers own sessions; the application delegate owns the backend lifetime.

## Input Controller Lifecycle

`SquirrelInputController` subclasses `IMKInputController` and is the core input-method object.

- `init(server:delegate:client:)` stores the initial `IMKTextInput` client, calls `createSession()`, and registers local notification observers for ASCII-mode set/report requests.
- `createSession()` chooses a client bundle identifier, creates a librime session with `rimeAPI.create_session()`, clears `schemaId`, and applies app-specific options.
- `destroySession()` calls `rimeAPI.destroy_session(session)` and clears chord typing state.
- `deinit` destroys the session.
- `activateServer(_:)` refreshes the current client, optionally overrides the keyboard layout from `keyboard_layout`, clears local preedit cache, and updates the menu-bar status label from `ascii_mode` if a session already exists.
- `deactivateServer(_:)` hides palettes, commits the current composition to the client, and releases the client reference.
- `commitComposition(_:)` commits raw pending librime input via `client.insertText`, then clears the librime composition.

The controller keeps `client` weak. Always guard client access. An input method may be activated, deactivated, or retargeted by macOS at awkward times.

## Input Update Loop

The critical loop is `handle(_:client:) -> Bool` in `SquirrelInputController`.

1. Ensure there is a valid librime session. If `session == 0` or `find_session(session)` fails, call `createSession()`.
2. Update the weak `IMKTextInput` client from `sender` when possible.
3. Detect client app bundle ID changes and apply `app_options/<bundle-id>` from `squirrel.yaml`.
4. For `.flagsChanged`:
   - Compute changed modifier flags by comparing with `lastModifiers`.
   - Convert modifiers with `SquirrelKeycode.osxModifiersToRime`.
   - Validate or infer modifier keycode. This protects against remote desktop tools sending bogus keycode 0 for modifier events.
   - Handle caps lock specially because librime expects `XK_Caps_Lock` before lock-mask state changes.
   - Process modifier releases before presses to handle delayed release events.
   - Update `lastModifiers` and call `rimeUpdate()`.
5. For `.keyDown`:
   - Ignore Command-modified shortcuts so the client application receives them.
   - Choose `charactersIgnoringModifiers` or `characters` depending on modifiers and ASCII/non-ASCII behavior.
   - Convert keycode/character/modifiers to librime keycode and masks.
   - Call `processKey(...)`.
   - Call `rimeUpdate()` when a valid rime keycode was processed.
6. Return `true` only when the event was handled and should not continue to the client application.

`recognizedEvents(_:)` returns key-down and flags-changed masks only.

## Key Processing Details

`processKey(_:, modifiers:)` is the narrow frontend/backend key boundary.

- Before calling librime, it synchronizes `_linear` and `_vertical` options from the current panel theme. Arrow-key behavior can depend on candidate layout and text orientation.
- It calls `rimeAPI.process_key(session, keycode, modifiers)`.
- If librime does not handle a Vim-like command-mode escape (`Esc`, `Ctrl-C`, `Ctrl-[`) and `vim_mode` is set, it forces `ascii_mode` on unless already in ASCII mode.
- If librime handles a key while `_chord_typing` is active, printable keys and modifiers are recorded and later released by a timer. Non-chording keys clear the chord buffer.

`MacOSKeyCodes.swift` is intentionally centralized. Add key translations there rather than scattering keycode conditionals through the controller.

## Rime Update and Dataflow

`rimeUpdate(clearReservedComments:)` consumes all frontend-visible librime state after key processing, paging, selection, caret movement, or plugin UI refresh.

Main sequence:

1. Clear reserved comment UI hints unless the caller explicitly preserves them.
2. `rimeConsumeCommittedText()` calls `get_commit`, inserts committed text into the client, frees the commit struct, resets local preedit, and hides the panel.
3. `get_status` detects schema changes:
   - reloads schema-specific settings through the app delegate;
   - calculates `inlinePreedit` and `inlineCandidate` using panel config plus librime options (`no_inline`, `inline`);
   - sets librime `soft_cursor` to the inverse of inline preedit.
4. `get_context` reads composition and menu state:
   - preedit string;
   - selected segment byte offsets converted to Swift indices;
   - cursor position;
   - candidate texts, comments, labels, page number, last-page flag, highlighted index.
5. It updates marked text through `show(preedit:selRange:caretPos:)`.
6. It updates the candidate panel through `showPanel(...)` unless no context is available, in which case it hides palettes.
7. It frees the librime context.

The text path is:

`NSEvent` -> `SquirrelInputController.handle` -> `processKey` -> `rimeAPI.process_key` -> `rimeUpdate` -> `get_commit`/`get_status`/`get_context` -> `client.insertText` and/or `client.setMarkedText` plus `SquirrelPanel.update`.

## Marked Text and Commit Rules

- Committed text must go through `client.insertText(_, replacementRange: .empty)`.
- Active composition should go through `client.setMarkedText(_, selectionRange:, replacementRange: .empty)`.
- `show(preedit:selRange:caretPos:)` caches the last marked preedit, caret, and selected range to avoid redundant marked-text calls.
- When non-inline preedit is configured, the controller may set a full-width space (`U+3000`) as marked text so clients such as iTerm2 do not echo every raw preedit character.
- `commitComposition(_:)` commits raw pending librime input during deactivation. This matters when macOS switches input sources or the focused text client changes.

Input methods must be conservative about when they consume events. Incorrect `true` returns drop app shortcuts or text; incorrect `false` returns can duplicate input.

## Candidate Panel Flow

The app delegate creates one shared `SquirrelPanel` during `applicationWillFinishLaunching`. The active input controller assigns itself to `panel.inputController` before updating the panel.

`showPanel(...)` gets cursor geometry from `client.attributes(forCharacterIndex:lineHeightRectangle:)`, stores it in `panel.position`, and calls `panel.update(...)`.

`SquirrelPanel.update(...)`:

- stores the latest preedit/candidate state;
- builds a single attributed string containing preedit and candidate rows;
- applies theme attributes, candidate labels, comments, semantic comment colors, no-break hints, and paragraph styles;
- updates the `NSTextView` storage and layout orientation;
- forces TextKit layout before measuring geometry;
- calls `SquirrelView.drawView(...)` for background/highlight paths;
- calls `show()` to position and display the panel.

`SquirrelPanel.show()`:

- chooses screen based on cursor position;
- sets effective appearance;
- measures text with TextKit 2;
- constrains oversized panels to most of the screen and scales via content-view bounds;
- positions normal panels near the cursor, with special handling for vertical text;
- applies content-view rotation for vertical mode;
- configures translucency background (`NSGlassEffectView` on macOS 26+, `NSVisualEffectView` otherwise);
- orders the nonactivating panel front.

Mouse and scroll events on the panel are forwarded back to the input controller:

- click candidate -> `selectCandidate(_:)` -> `rimeUpdate()`;
- click/scroll paging controls -> `page(up:)` -> `rimeUpdate()`;
- click preedit position -> `moveCaret(forward:)` -> `rimeUpdate()`.

## Custom Drawing

`SquirrelView` owns the drawing and hit-testing model.

- It uses an `NSTextView` with TextKit 2 layout to measure actual rendered text segments.
- `contentRect` and `contentRect(range:)` enumerate text layout segments to compute bounds.
- `draw(_:)` builds Core Graphics paths for panel background, preedit background, candidate backgrounds, highlighted candidate, highlighted preedit range, border, shadow, and paging controls.
- `shape` is also used as the panel background mask and hit-test region.
- `click(at:)` maps mouse points back into TextKit offsets and candidate/preedit ranges.

When changing panel layout, preserve the order: set attributed text, set layout orientation, force layout, measure, draw paths, then show/reposition.

## Configuration Model

`SquirrelConfig` is a typed facade over `RimeConfig`.

- `openBaseConfig()` opens `squirrel` config.
- `open(schemaID:baseConfig:)` opens schema config and falls back to base config for missing values.
- `getBool`, `getDouble`, `getString`, and `getColor` cache successful reads.
- `getAppOptions(_:)` reads boolean options under `app_options/<bundle-id>`.

`SquirrelTheme.load(config:dark:)` reads global `style/*`, then optional preset color scheme settings. Per-color-scheme values can override style values for layout, color, fonts, alpha, spacing, and candidate formatting.

Important theme flags:

- `candidate_list_layout`: linear vs stacked candidate list.
- `text_orientation`: horizontal vs vertical.
- `inline_preedit`, `inline_candidate`: marked text vs panel display strategy.
- `translucency`, `mutual_exclusive`, `memorize_size`, `show_paging`.
- `candidate_format`: template using `[label]`, `[candidate]`, `[comment]`; legacy `%c` and `%@` are normalized.

## Notifications and External Commands

The app uses distributed notifications for process-to-running-instance commands.

- `SquirrelReloadNotification` -> deploy: shutdown Rime, reinitialize, reload settings.
- `SquirrelSyncNotification` -> `sync_user_data()`.
- `SquirrelToggleASCIIModeNotification` -> posts local `SquirrelSetASCIIModeNotification` with `Bool`.
- `SquirrelGetASCIIModeNotification` -> posts local report request; active controller responds with `SquirrelASCIIModeResponse` (`ascii` or `nascii`).
- `kTISNotifySelectedKeyboardInputSourceChanged` -> updates status item visibility and finalizes stranded compositions.

The finalization fallback is important: some macOS/input-source switch paths may not call `deactivateServer`. When the selected input source no longer starts with `im.rime.inputmethod.Squirrel`, the app delegate calls `deactivateServer` on the panel's current input controller to avoid orphaned composition/panel state.

## Librime Notification Handler

`notificationHandler(...)` is installed by `setupRime()` and receives backend notifications.

- `deploy/start`, `deploy/success`, `deploy/failure`: show user notifications.
- `option`: parses enabled/disabled option names, gets abbreviated and long state labels from librime, updates status icon for `ascii_mode`, and optionally shows a status message on the panel.
- `property` where the value starts with `_` and contains `=`: treats it as a reserved frontend property and calls `handleReservedProperty(...)` on the current panel input controller on the main actor.
- `schema`: when notifications are enabled, extracts and shows schema name.

Reserved properties currently include:

- `_comment_highlight`: comma-separated candidate indices to draw with `accent_text_color`.
- `_comment_warning`: comma-separated candidate indices to draw with `warning_text_color`.
- `_refresh_ui`: requests `rimeUpdate(clearReservedComments: false)`.

Reserved-property values are query-string compatible; bare comma lists are parsed under the `value` field.

## Installer and Input Source Registration

`SquirrelInstaller` wraps Text Input Source Services.

- Input modes are `im.rime.inputmethod.Squirrel.Hans` and `im.rime.inputmethod.Squirrel.Hant`; `Hans` is the primary default.
- `register()` calls `TISRegisterInputSource` for `/Library/Input Library/Squirrel.app` when no Squirrel modes are already enabled.
- `enable`, `disable`, and `select` operate on TIS input sources.
- `currentInputSourceID()` reads `TISCopyCurrentKeyboardInputSource()` and is used to control status item visibility and stranded-composition cleanup.

`Info.plist` must stay consistent with `InputSource.swift`: input mode identifiers, `InputMethodConnectionName`, and controller class names are part of macOS input method registration.

## Backend Bridge Conventions

The Swift/C boundary uses generated librime types plus helpers in `BridgingFunctions.swift`.

- Initialize librime structs with `.rimeStructInit()` so memory is zeroed and `data_size` is set correctly.
- Free librime-owned structs after successful reads: commits with `free_commit`, statuses with `free_status`, contexts with `free_context`.
- `setCString(_:to:)` duplicates Swift strings for C fields. Be mindful that duplicated C strings are manually allocated.
- `RimeStringSlice.asString` must respect `.length`; do not replace it with `String(cString:)` for abbreviated labels.

## Coding and Comment Style

Follow the existing Swift/AppKit style unless there is a strong local reason to do otherwise.

- Types use PascalCase: `SquirrelInputController`, `ReservedPropertyValue`, `SquirrelTheme`.
- Methods, properties, local variables, and enum cases use camelCase.
- Keep local acronym style consistent with nearby code: `rimeAPI`, `schemaId`, `currentApp`, `asciiMode`.
- Boolean names should read naturally with `is`, `has`, `can`, `should`, or a clear state noun when the existing API already uses one.
- Generated C bridge fields may keep snake_case names such as `data_size`; use narrow SwiftLint suppressions rather than renaming generated API concepts.
- Prefer `let` for values that do not change, `private` for implementation details, and `private(set)` when other types need read-only state.
- Keep IMK lifecycle and event handling in `SquirrelInputController`; keep global Rime/app lifetime in `SquirrelApplicationDelegate`.
- Keep config access in `SquirrelConfig` and configurable visual state in `SquirrelTheme`.
- Keep key translation in `MacOSKeyCodes`; do not scatter raw Carbon/Rime key mappings through input handling code.
- Keep candidate panel state and positioning in `SquirrelPanel`; keep drawing, geometry, and hit testing in `SquirrelView`.

Reuse existing helpers before adding new abstractions.

- Use `.rimeStructInit()` for librime structs that need zeroed memory and `data_size`.
- Use `setCString(_:to:)` when assigning Swift strings into Rime trait/config structs.
- Use the `?=` operator for optional config overrides in theme/config-loading code.
- Use `NSRange.empty` for the project's sentinel empty range.
- Use `RimeStringSlice.asString` for Rime slices because it respects the slice length.
- Use `SquirrelKeycode` for macOS-to-Rime key conversion.
- Extend `ReservedPropertyValue` for reserved-property parsing instead of adding one-off string parsing.
- Add a shared helper only when multiple call sites need the same non-trivial behavior. Avoid wrapping a single straightforward expression.

Comment style is intentionally sparse.

- Keep the simple file headers already used by the project.
- Keep SwiftLint directive comments exactly where they are needed.
- Use English for retained comments.
- Comments should explain why, ordering constraints, ownership, or platform/backend quirks. Do not restate what the next line does.
- Remove commented-out debug prints and temporary tracing instead of preserving them in source.
- Keep comments near IMK/librime event ordering, TextKit measurement constraints, vertical-mode coordinate transforms, C memory ownership, and plugin/frontend contracts.
- Prefer one compact explanatory comment over long branch-by-branch examples unless the example prevents a likely regression.

## Input Method Invariants

Keep these invariants in mind for any change:

- Global librime lifetime belongs to the app delegate; session lifetime belongs to input controllers.
- Every key event path that changes librime state should call `rimeUpdate()` exactly when frontend state needs to be consumed.
- Do not consume Command shortcuts in normal text input; let client applications handle them.
- Deactivation must hide the panel and commit or clear active composition so no marked text or panel is stranded.
- Always guard against nil or stale `IMKTextInput` clients.
- Convert librime byte offsets into Swift string indices before building `NSRange` values.
- Keep `get_context`, `get_status`, and `get_commit` free calls paired with successful reads.
- Preserve app-specific options on session creation and when the focused client bundle changes.
- Candidate panel geometry depends on TextKit layout results. Avoid measuring before layout is forced.
- Vertical text affects key behavior, layout orientation, content rotation, panel positioning, and scroll paging direction.
- `inlinePreedit` and `inlineCandidate` are determined jointly by theme config and librime options.
- Shared panel state should always point to the active input controller before candidate updates or mouse actions.

## Common Change Areas

For key handling changes:

1. Start in `SquirrelInputController.handle` and `processKey`.
2. Put reusable key mappings in `MacOSKeyCodes.swift`.
3. Preserve modifier ordering and caps-lock behavior.
4. Verify event consumption semantics.

For candidate UI changes:

1. Start in `SquirrelPanel.update` for text/attributes/data shaping.
2. Use `SquirrelTheme` for configurable style values.
3. Use `SquirrelView` for geometry, drawing, and hit testing.
4. Test horizontal, linear, vertical, paging, inline preedit, and no-candidate states.

For config changes:

1. Add reads in `SquirrelTheme` or `SquirrelConfig` only where the value belongs.
2. Keep base config and schema-specific fallback behavior intact.
3. Consider dark/light theme loading separately.

For lifecycle or command changes:

1. Start in `Main.swift` for command-line behavior.
2. Start in `SquirrelApplicationDelegate` for app-global observers, Rime setup, status item behavior, and termination.
3. Keep distributed notification names stable unless all callers are updated.

For librime plugin/frontend coordination:

1. Add reserved keys to `ReservedPropertyKey`.
2. Parse values in `ReservedPropertyValue` or in `handleReservedProperty`.
3. Apply UI effects in `SquirrelInputController` or `SquirrelPanel`, depending on whether the state belongs to the session or rendering.
4. Preserve `_refresh_ui` behavior for plugin-driven redraws.

## Validation Checklist

When possible, validate with Xcode build diagnostics or a full Xcode build. For behavior changes, manually exercise:

- input activation/deactivation in multiple apps;
- typing, committing, cancelling, and switching input sources mid-composition;
- ASCII mode toggle and status reporting;
- schema switching and schema-specific style reload;
- candidate selection by number key and mouse;
- paging by key, mouse, and scroll;
- inline and non-inline preedit;
- vertical and linear candidate layouts;
- deployment/reload and sync commands;
- app quit/log out cleanup.

Input-method bugs often appear as duplicated text, dropped shortcuts, orphaned candidate panels, stale marked text, or session-specific state leaking between client apps. Test around those failure modes first.
