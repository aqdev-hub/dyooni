import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return result
    }
    let channel = FlutterMethodChannel(name: "dyooni/voice_bluetooth", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, callback in
      guard call.method == "isHeadsetConnected" else {
        callback(FlutterMethodNotImplemented)
        return
      }
      let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
      callback(inputs.contains { $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE })
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
