import Flutter
import UIKit

/// Registers the duo_display host API with Flutter.
///
/// Flutter's protocols are not actor-isolated, but Flutter registers plugins
/// on the main thread: `@preconcurrency` asserts that at runtime.
@MainActor
public final class DuoDisplayPlugin: NSObject, @preconcurrency FlutterPlugin {
  public static func register(with registrar: any FlutterPluginRegistrar) {
    let host = DuoDisplayHost(registrar: registrar)
    // The channel handlers keep the host alive for the engine's lifetime.
    DuoDisplayHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: host)
  }
}

/// Owns the geometry observer and answers Dart calls. Below iOS 27.1, or on
/// a device without a hinge, it reports unsupported and never sends geometry.
@MainActor
final class DuoDisplayHost {
  /// Foldable iPhone model identifiers. A device missing from this list is
  /// still supported as soon as UIKit delivers a hinge state.
  private static let foldableModels: Set<String> = ["iPhone19,4"]

  private weak var registrar: (any FlutterPluginRegistrar)?
  private let flutterApi: DuoDisplayFlutterApi
  /// A `DuoGeometryObserver`, typed as `UIView` because stored properties
  /// cannot be limited to iOS 27.1.
  private var observer: UIView?

  init(registrar: any FlutterPluginRegistrar) {
    self.registrar = registrar
    flutterApi = DuoDisplayFlutterApi(binaryMessenger: registrar.messenger())
    attachObserverIfPossible()
  }

  var supported: Bool {
    guard #available(iOS 27.1, *) else { return false }
    attachObserverIfPossible()
    let observer = observer as? DuoGeometryObserver
    return Self.foldableModels.contains(Self.modelIdentifier) || observer?.hasHinge == true
  }

  var latestSnapshot: DuoGeometryMessage? {
    guard #available(iOS 27.1, *), supported else { return nil }
    return (observer as? DuoGeometryObserver)?.snapshot
  }

  /// With the UIScene lifecycle, the Flutter view controller usually does not
  /// exist yet when plugins register, so attaching is retried on Dart calls.
  private func attachObserverIfPossible() {
    guard #available(iOS 27.1, *), observer == nil,
      let view = registrar?.viewController?.view
    else { return }
    let observer = DuoGeometryObserver()
    observer.onChange = { [weak self] snapshot in self?.send(snapshot) }
    observer.attach(to: view)
    self.observer = observer
  }

  private func send(_ snapshot: DuoGeometryMessage) {
    guard supported else { return }
    let flutterApi = flutterApi
    // Snapshots are at least the settle delay apart, so these sends cannot
    // overtake each other. A failure only means Dart is not listening yet;
    // Dart asks for current() when it starts listening.
    Task { try? await flutterApi.onGeometryChanged(geometry: snapshot) }
  }

  private static var modelIdentifier: String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return simulated
    }
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafeBytes(of: &systemInfo.machine) { buffer in
      String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    }
  }
}

// Pigeon's protocol is not actor-isolated, but Flutter delivers platform
// channel messages on the main thread: assert that rather than hop.
extension DuoDisplayHost: @preconcurrency DuoDisplayHostApi {
  func isSupported() throws -> Bool { supported }
  func current() throws -> DuoGeometryMessage? { latestSnapshot }
}
