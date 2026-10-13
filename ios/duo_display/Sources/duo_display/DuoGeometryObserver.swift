import UIKit

/// An invisible view pinned to the Flutter view. It re-reads the iPhone Duo
/// geometry whenever it may have changed (layout pass, vertical bar trait
/// change, hinge update) and reports settled snapshots that differ from the
/// previous one.
///
/// Region frames are in this view's coordinate space, which is the Flutter
/// view's since both share the same bounds.
@available(iOS 27.1, *)
final class DuoGeometryObserver: UIView {
  /// Called with each settled snapshot that differs from the previous one.
  var onChange: ((DuoGeometryMessage) -> Void)?

  /// The last settled snapshot.
  private(set) var snapshot: DuoGeometryMessage?

  /// Whether UIKit has delivered a hinge state, which only happens in a
  /// hierarchy that has a hinge.
  private(set) var hasHinge = false

  /// Waits before each read, counted from the last event. Transitions emit
  /// bursts of intermediate states (regions of the previous screen,
  /// provisional status column, hinge updates every ~50 ms while the device
  /// folds), so the first read waits until nothing changed for 150 ms. Some
  /// regions still change later without any event this view receives, so a
  /// second read follows one second after the last event.
  private static let readDelays: [Duration] = [.milliseconds(150), .milliseconds(850)]

  private var hinge: UIHinge?
  private var settleTask: Task<Void, Never>?

  init() {
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    backgroundColor = .clear

    // The hinge is push-based: UIKit calls the handler with the initial
    // state, then on every change. Nothing can be polled from layoutSubviews.
    addInteraction(UIHingeInteraction { [weak self] _, update in
      guard let self else { return }
      hinge = update.hinge
      if update.hinge != nil { hasHinge = true }
      scheduleRead()
    })

    let traits: [UITrait] = UITraitCollection.systemTraitsAffectingVerticalBarEdge
      + [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    registerForTraitChanges(traits) { (self: Self, _: UITraitCollection) in
      self.scheduleRead()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  /// Adds the observer behind every other subview of `view`, pinned to its
  /// four edges.
  func attach(to view: UIView) {
    translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(self, at: 0)
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: view.leadingAnchor),
      trailingAnchor.constraint(equalTo: view.trailingAnchor),
      topAnchor.constraint(equalTo: view.topAnchor),
      bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Pitfall 1: regions are empty during the first layout passes, then
    // appear. Re-read on every pass instead of reading once.
    scheduleRead()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    scheduleRead()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    // After a screen switch, the status column appears with a safe area
    // update that usually brings no layout pass to this view: its bounds do
    // not change.
    scheduleRead()
  }

  private func scheduleRead() {
    settleTask?.cancel()
    settleTask = Task { [weak self] in
      for delay in DuoGeometryObserver.readDelays {
        do {
          try await Task.sleep(for: delay)
        } catch {
          return
        }
        self?.read()
      }
    }
  }

  private func read() {
    guard let window, let scene = window.windowScene else { return }
    let regions = reservedRegions(kind: .division, options: .includeInactive)
      + reservedRegions(kind: .occlusion, options: .includeInactive)
    // Pitfall 1 again: before the first regions and hinge state arrive, a
    // snapshot carries no information.
    guard hinge != nil || !regions.isEmpty else { return }

    let snapshot = DuoGeometryMessage(
      viewSize: SizeMessage(bounds.size),
      windowSize: SizeMessage(window.bounds.size),
      // Pitfall 2: UIScreen.main keeps reporting the outer screen (466x678)
      // while the inner one is in use. The scene's screen is the right one.
      screenSize: SizeMessage(scene.screen.bounds.size),
      hingeStatus: hinge.map { HingeStatusMessage($0.status) },
      hingeAngle: hinge.map { Double($0.angle) },
      verticalBarEdge: VerticalBarEdgeMessage(traitCollection.verticalBarEdge),
      regions: regions.map(RegionMessage.init)
    )
    guard snapshot != self.snapshot else { return }
    self.snapshot = snapshot
    onChange?(snapshot)
  }
}

// MARK: - UIKit to message conversions

extension SizeMessage {
  init(_ size: CGSize) {
    self.init(width: size.width, height: size.height)
  }
}

extension RectMessage {
  init(_ rect: CGRect) {
    self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
  }
}

@available(iOS 27.1, *)
extension RegionMessage {
  init(_ region: UIView.ReservedRegion) {
    self.init(
      kind: region.kind == .division ? .division : .occlusion,
      active: region.isActive,
      frame: RectMessage(region.frame)
    )
  }
}

@available(iOS 27.1, *)
extension HingeStatusMessage {
  init(_ status: UIHinge.Status) {
    switch status {
    case .closed: self = .closed
    case .partiallyOpen: self = .partiallyOpen
    case .fullyOpen: self = .fullyOpen
    case .unknown: self = .unknown
    @unknown default: self = .unknown
    }
  }
}

@available(iOS 27.1, *)
extension VerticalBarEdgeMessage {
  init(_ edge: UIVerticalBarEdge) {
    switch edge {
    case .leading: self = .leading
    case .trailing: self = .trailing
    case .unspecified: self = .unspecified
    @unknown default: self = .unspecified
    }
  }
}
