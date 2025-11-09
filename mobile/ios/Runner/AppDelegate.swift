import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up ProofMode platform channel
    setupProofModeChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupProofModeChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ ProofMode: Could not get FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "org.openvine/proofmode",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "generateProof":
        guard let args = call.arguments as? [String: Any],
              let mediaPath = args["mediaPath"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Media path is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: generateProof called for: \(mediaPath)")

        // TODO: Integrate ProofMode iOS library when available
        // For now, iOS ProofMode is not yet implemented
        // The iOS port at https://gitlab.com/guardianproject/proofmode/proofmode-ios
        // does not have a published CocoaPods library yet
        NSLog("⚠️ ProofMode: iOS library not yet available - returning null")
        result(nil)

      case "getProofDir":
        guard let args = call.arguments as? [String: Any],
              let proofHash = args["proofHash"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Proof hash is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: getProofDir called for hash: \(proofHash)")
        NSLog("⚠️ ProofMode: iOS library not yet available - returning null")
        result(nil)

      case "isAvailable":
        // iOS ProofMode library is not yet available
        // When integrated, this should return true
        NSLog("🔐 ProofMode: isAvailable check - currently false on iOS")
        result(false)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ ProofMode: Platform channel registered (iOS stub implementation)")
  }
}
