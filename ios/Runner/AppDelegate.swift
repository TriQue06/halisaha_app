import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Push (APNs) kaydını açılışta kendimiz başlatıyoruz.
    //
    // UIScene / implicit engine yapısında eklentiler bu metottan SONRA
    // kaydediliyor; firebase_messaging'in kendi registerForRemoteNotifications
    // çağrısı bu yüzden hiç çalışmıyordu ve iPhone'lar APNs token'ı alamıyordu
    // (push_diagnostics: apns_null, izin: authorized). Gelen token'ı
    // FlutterAppDelegate eklentiye (ve Firebase'e) iletiyor.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
