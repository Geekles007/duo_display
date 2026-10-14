// DuoProbe: a single-file UIKit app that dumps the iPhone Duo display geometry
// as one JSON line per event (layout pass, trait change, hinge update), plus a
// "tick" line whenever regions change with no event at all.
//
// Build and run with tool/probe/run.sh. Requires the iOS 27.1 SDK.

import UIKit

private let launchDate = Date()

// MARK: - JSON model

struct Size: Encodable { let w: Double, h: Double }
struct Rect: Encodable, Equatable { let x: Double, y: Double, w: Double, h: Double }
struct Insets: Encodable, Equatable { let top: Double, left: Double, bottom: Double, right: Double }

struct Region: Encodable, Equatable {
  let kind: String
  /// Opaque: prints "ID()", and the Objective-C identifier only prints its
  /// address. Camera and status column can only be told apart by geometry.
  let id: String
  let active: Bool
  let frame: Rect
  let margins: Insets
}

struct Hinge: Encodable {
  let status: String
  let angleRad: Double
  let angleDeg: Double
}

struct Sample: Encodable {
  let pass: Int
  let t: Double
  let trigger: String
  let window: Rect?
  let viewBounds: Size
  let sceneScreenBounds: Size?
  let sceneScreenScale: Double?
  let mainScreenBounds: Size
  let interfaceOrientation: String?
  let horizontalSizeClass: String
  let verticalSizeClass: String
  let verticalBarEdge: String
  let safeArea: Insets
  /// nil until the first UIHingeInteraction update, or when the hierarchy has no hinge.
  let hinge: Hinge?
  let hingeUpdates: Int
  let regionCount: Int
  let regions: [Region]
}

// MARK: - Conversions

extension Size { init(_ s: CGSize) { self.init(w: s.width, h: s.height) } }
extension Rect {
  init(_ r: CGRect) { self.init(x: r.origin.x, y: r.origin.y, w: r.width, h: r.height) }
}
extension Insets {
  init(_ i: UIEdgeInsets) { self.init(top: i.top, left: i.left, bottom: i.bottom, right: i.right) }
}

extension UIUserInterfaceSizeClass {
  var name: String {
    switch self {
    case .compact: "compact"
    case .regular: "regular"
    case .unspecified: "unspecified"
    @unknown default: "unknown(\(rawValue))"
    }
  }
}

extension UIVerticalBarEdge {
  var name: String {
    switch self {
    case .unspecified: "unspecified"
    case .leading: "leading"
    case .trailing: "trailing"
    @unknown default: "unknown(\(rawValue))"
    }
  }
}

extension UIHinge.Status {
  var name: String {
    switch self {
    case .unknown: "unknown"
    case .closed: "closed"
    case .partiallyOpen: "partiallyOpen"
    case .fullyOpen: "fullyOpen"
    @unknown default: "unknown(\(rawValue))"
    }
  }
}

extension UIInterfaceOrientation {
  var name: String {
    switch self {
    case .portrait: "portrait"
    case .portraitUpsideDown: "portraitUpsideDown"
    case .landscapeLeft: "landscapeLeft"
    case .landscapeRight: "landscapeRight"
    case .unknown: "unknown"
    @unknown default: "unknown(\(rawValue))"
    }
  }
}

// MARK: - Probe view

final class ProbeView: UIView {
  private var pass = 0
  private var hingeUpdates = 0
  private var hinge: Hinge?
  private var lastRegions: [Region] = []
  private var sampler: Task<Void, Never>?
  /// Only with DUOPROBE_VSYNC=1 (run.sh: VSYNC=1): its line every second
  /// would keep snap.sh from ever seeing a settled log.
  private let vsync = ProcessInfo.processInfo.environment["DUOPROBE_VSYNC"] == "1"
    ? VsyncMeter() : nil
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()
  private let label = UILabel()
  private var taps = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    label.text = "DuoProbe: JSON on stdout"
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    addSubview(label)
    // A tap counter, to check how fast the screen reflects input.
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countTap)))

    // The hinge is push-based: UIKit calls the handler with the initial state,
    // then on every change. A nil hinge means the hierarchy has none.
    addInteraction(UIHingeInteraction { [weak self] _, update in
      guard let self else { return }
      hingeUpdates += 1
      hinge = update.hinge.map {
        Hinge(status: $0.status.name, angleRad: $0.angle, angleDeg: $0.angle * 180 / .pi)
      }
      emit("hinge")
    })

    let traits: [UITrait] = UITraitCollection.systemTraitsAffectingVerticalBarEdge
      + [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    registerForTraitChanges(traits) { (self: Self, _: UITraitCollection) in
      self.emit("traits")
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    sampler?.cancel()
    guard window != nil else { return }
    // Polls the regions to catch changes that trigger no layout pass, trait
    // change or hinge update. Only logs when something actually changed.
    sampler = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(250))
        guard let self, currentRegions() != lastRegions else { continue }
        emit("tick")
      }
    }
  }

  @objc private func countTap() {
    taps += 1
    label.text = "DuoProbe: taps \(taps)"
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    label.frame = bounds
    // Pitfall 1: regions are empty for the first 6 to 9 layout passes, so we
    // log every pass instead of reading once.
    emit("layout")
  }

  private func currentRegions() -> [Region] {
    let regions = reservedRegions(kind: .division, options: .includeInactive)
      + reservedRegions(kind: .occlusion, options: .includeInactive)
    return regions.map { region in
      Region(
        kind: region.kind == .division ? "division" : "occlusion",
        id: region.id.description,
        active: region.isActive,
        frame: Rect(region.frame),
        margins: Insets(region.margins)
      )
    }
  }

  private func emit(_ trigger: String) {
    if let scene = window?.windowScene { vsync?.follow(scene) }
    pass += 1
    let regions = currentRegions()
    lastRegions = regions
    let scene = window?.windowScene
    let sample = Sample(
      pass: pass,
      t: Date().timeIntervalSince(launchDate),
      trigger: trigger,
      window: window.map { Rect($0.frame) },
      viewBounds: Size(bounds.size),
      sceneScreenBounds: scene.map { Size($0.screen.bounds.size) },
      sceneScreenScale: scene.map { $0.screen.scale },
      // Pitfall 2: the deprecated main screen reports the outer screen
      // (466x678) even on the inner one. Logged only to show the discrepancy.
      mainScreenBounds: Size(UIScreen.main.bounds.size),
      interfaceOrientation: scene?.effectiveGeometry.interfaceOrientation.name,
      horizontalSizeClass: traitCollection.horizontalSizeClass.name,
      verticalSizeClass: traitCollection.verticalSizeClass.name,
      verticalBarEdge: traitCollection.verticalBarEdge.name,
      safeArea: Insets(safeAreaInsets),
      hinge: hinge,
      hingeUpdates: hingeUpdates,
      regionCount: regions.count,
      regions: regions
    )
    guard var line = try? encoder.encode(sample) else { return }
    line.append(0x0A)
    // Unbuffered write, so lines reach the console PTY immediately.
    FileHandle.standardOutput.write(line)
  }
}

// MARK: - Vsync meter

/// Counts, every second, the ticks of a display link created the way the
/// Flutter engine creates its own (`CADisplayLink(target:selector:)`, bound to
/// the main screen) and of one from `UIWindowScene.displayLink`, which iOS 27
/// retargets when the scene moves between displays. Logged as "vsync {...}"
/// lines that snap.sh skips; enabled with DUOPROBE_VSYNC=1 only, since a line
/// every second would keep snap.sh from ever seeing a settled log.
@MainActor
final class VsyncMeter: NSObject {
  private var mainTicks = 0
  private var sceneTicks = 0
  private var sceneLink: CADisplayLink?
  private weak var scene: UIWindowScene?

  override init() {
    super.init()
    CADisplayLink(target: self, selector: #selector(mainTick)).add(to: .main, forMode: .common)
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.report() }
    }
  }

  /// Creates the scene display link once the window has a scene.
  func follow(_ scene: UIWindowScene) {
    guard scene !== self.scene else { return }
    self.scene = scene
    sceneLink?.invalidate()
    sceneLink = scene.displayLink(target: self, selector: #selector(sceneTick))
    sceneLink?.add(to: .main, forMode: .common)
  }

  @objc private func mainTick() { mainTicks += 1 }
  @objc private func sceneTick() { sceneTicks += 1 }

  private func report() {
    let size = scene.map { "\(Int($0.screen.bounds.width))x\(Int($0.screen.bounds.height))" } ?? "none"
    let line = "vsync {\"t\":\(Date().timeIntervalSince(launchDate)),\"main\":\(mainTicks),\"scene\":\(sceneTicks),\"sceneScreen\":\"\(size)\"}\n"
    FileHandle.standardOutput.write(Data(line.utf8))
    mainTicks = 0
    sceneTicks = 0
  }
}

final class ProbeViewController: UIViewController {
  override func loadView() { view = ProbeView() }
}

// MARK: - App lifecycle

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = ProbeViewController()
    window.makeKeyAndVisible()
    self.window = window
  }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}
