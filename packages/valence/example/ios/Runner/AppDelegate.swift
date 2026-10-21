import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeValenceDirectoryFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Keeps `<appSupport>/valence/` out of iCloud and iTunes backups (contracts §2.4).
  ///
  /// A restore has to start clean from the built-in bundle: a restored `installId` clones the rollout
  /// cohort onto a second device and can carry a stale trial with it. The SQLite database lives *outside*
  /// this directory and is deliberately backed up, because it holds the user's own data.
  ///
  /// iOS is experimental and untested in Valence — there is no Apple hardware on the machines it is
  /// developed on — so treat this as specified-and-implemented, not verified.
  private func excludeValenceDirectoryFromBackup() {
    guard
      let support = try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    else { return }
    var dir = support.appendingPathComponent("valence", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? dir.setResourceValues(values)
  }
}
