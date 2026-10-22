import AppKit
import Carbon
import Foundation

// Installer-only helper, invoked in the console user's GUI session:
//   prepare       -> write a JSON snapshot, switch keyboards, quit the old process
//   restore FILE  -> register the installed bundle and restore the saved input sources
// The shell passes the snapshot between phases and also uses restore after a failed
// preparation. Standard installations only capture state and use the original script.

let bundleID = "im.rime.inputmethod.Squirrel"
let appURL = URL(
  fileURLWithPath: "/Library/Input Methods/Squirrel.app",
  isDirectory: true
)
let modeIDs = [bundleID + ".Hans", bundleID + ".Hant"]

/// State captured before changing the user's keyboard or stopping Squirrel.
/// The UID prevents restoration into a different login session; mode IDs preserve
/// the user's enabled Simplified/Traditional Chinese modes independently of selection.
struct SourceState: Codable {
  let hotUpdate: Bool
  let userID: uid_t
  let enabledModes: [String]
  let selectedID: String
}

// MARK: - Text Input Source Services (TIS)

/// TIS owns the returned property value; the Get API does not transfer ownership.
func property(_ source: TISInputSource, _ key: CFString) -> Any? {
  guard let raw = TISGetInputSourceProperty(source, key) else {
    return nil
  }

  return Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
}

func sourceID(_ source: TISInputSource) -> String {
  property(source, kTISPropertyInputSourceID) as? String ?? ""
}

func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
  (property(source, key) as? NSNumber)?.boolValue ?? false
}

/// Include disabled sources: restoration must find modes before enabling them.
func allSources() -> [TISInputSource] {
  TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
}

/// Re-query after registration or enablement instead of retaining a stale source list.
func source(_ id: String) -> TISInputSource? {
  allSources().first { sourceID($0) == id }
}

// MARK: - State and completion checks

/// Combine the installer's per-user preference with the current input-source state.
func snapshot() -> SourceState {
  // Match the pane's eligibility check: an incomplete bundle needs a standard install.
  let bundle = Bundle(url: appURL)
  let installed = bundle?.bundleIdentifier == bundleID
    && bundle?.executableURL.map {
      FileManager.default.isExecutableFile(atPath: $0.path)
    } == true

  // Only an explicit false opts out; a missing preference defaults to hot update
  // when a valid installation exists. First installs always use the standard path.
  let hotUpdate = installed
    && (UserDefaults(suiteName: "im.rime.inputmethod.Squirrel.Installer")?
      .object(forKey: "HotUpdate") as? Bool) != false

  return SourceState(
    hotUpdate: hotUpdate,
    userID: getuid(),
    enabledModes: allSources().filter {
      modeIDs.contains(sourceID($0))
        && flag($0, kTISPropertyInputSourceIsEnabled)
    }.map(sourceID),
    selectedID: sourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
  )
}

func require(_ condition: Bool, _ message: String) throws {
  if !condition {
    throw NSError(
      domain: "SquirrelUpdate",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}

func check(_ status: OSStatus, _ operation: String) throws {
  try require(status == noErr, "\(operation) failed (\(status))")
}

/// Give asynchronous TIS changes and process termination up to three seconds.
/// API success alone does not establish that the requested state is already visible.
func waitFor(_ predicate: () -> Bool) -> Bool {
  for _ in 0..<30 {
    if predicate() {
      return true
    }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
  }

  return predicate()
}

// MARK: - Installer phases

/// Save recovery state before any mutation, then release the old input-method process.
func prepare() throws {
  let state = snapshot()

  // stdout is the shell's JSON transport. Flush before changing anything so a
  // partially failed preparation can still restore the original selection.
  print(String(decoding: try JSONEncoder().encode(state), as: UTF8.self))
  fflush(stdout)

  guard state.hotUpdate else {
    return
  }

  // Switch away before quitting, so clients release the old input-method connection.
  if state.selectedID.hasPrefix(bundleID) {
    let fallback = allSources().first {
      !sourceID($0).hasPrefix(bundleID)
        && flag($0, kTISPropertyInputSourceIsEnabled)
        && flag($0, kTISPropertyInputSourceIsSelectCapable)
        && flag($0, kTISPropertyInputSourceIsASCIICapable)
    }

    try require(
      fallback != nil,
      "No enabled ASCII keyboard is available for the update."
    )
    try check(TISSelectInputSource(fallback!), "Select fallback keyboard")
    try require(
      waitFor { !snapshot().selectedID.hasPrefix(bundleID) },
      "Could not switch away from Squirrel."
    )
  }

  let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: bundleID
  )
  for app in applications {
    app.terminate()
  }
  try require(
    waitFor { applications.allSatisfy(\.isTerminated) },
    "Squirrel did not quit; update stopped before replacing files."
  )
}

/// Rebuild registration, enable the saved modes, then restore the active selection.
/// Also used by the shell to recover from preparation or shared-data build failures.
func restore(_ state: SourceState) throws {
  guard state.hotUpdate else {
    return
  }

  // Fast user switching must not apply one user's saved modes to another session.
  try require(
    state.userID == getuid(),
    "The console user changed during installation; restore the original user session first."
  )

  // An existing enabled entry may refer to the bundle before it was updated.
  try check(TISRegisterInputSource(appURL as CFURL), "Register updated Squirrel")
  try require(
    waitFor { source(bundleID) != nil },
    "Updated Squirrel is missing from the input source registry."
  )

  // TIS requires the parent input method to be enabled before its individual modes.
  // Keep all modes disabled if that was the user's original configuration.
  if !state.enabledModes.isEmpty {
    try check(TISEnableInputSource(source(bundleID)!), "Enable parent input method")
    try require(
      waitFor {
        source(bundleID).map { flag($0, kTISPropertyInputSourceIsEnabled) } ?? false
      },
      "Parent input method did not become enabled."
    )
  }

  for id in state.enabledModes {
    try require(source(id) != nil, "Input mode disappeared: \(id)")
    try check(TISEnableInputSource(source(id)!), "Enable \(id)")
    try require(
      waitFor {
        source(id).map { flag($0, kTISPropertyInputSourceIsEnabled) } ?? false
      },
      "Input mode did not become enabled: \(id)"
    )
  }

  // Restore Squirrel only if it was previously selected; leave other keyboard choices alone.
  if state.selectedID.hasPrefix(bundleID) {
    guard let selected = source(state.selectedID) else {
      throw NSError(
        domain: "SquirrelUpdate",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Previously selected mode is missing."]
      )
    }

    try check(TISSelectInputSource(selected), "Restore selected input mode")
    try require(
      waitFor { snapshot().selectedID == state.selectedID },
      "Selected input mode was not restored."
    )
  }

  print("Squirrel registration and input-source state restored.")
}

// MARK: - Command-line entry point

// The package runs as root, but its shell dispatcher launches this helper as the
// console user with launchctl + sudo. Errors go to stderr and fail the install phase.
do {
  try require(
    getuid() != 0,
    "Run input-source operations as the logged-in user, not root."
  )

  switch CommandLine.arguments.dropFirst().first {
  case "prepare":
    try prepare()

  case "restore":
    try require(CommandLine.arguments.count == 3, "Missing saved input-source state.")
    let state = try JSONDecoder().decode(
      SourceState.self,
      from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
    )
    try restore(state)

  default:
    throw NSError(
      domain: "SquirrelUpdate",
      code: 3,
      userInfo: [NSLocalizedDescriptionKey: "Expected prepare or restore."]
    )
  }
} catch {
  fputs("Squirrel update: \(error.localizedDescription)\n", stderr)
  exit(1)
}
