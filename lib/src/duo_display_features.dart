import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:duo_display/src/duo_display.dart';
import 'package:duo_display/src/duo_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Reports the iPhone Duo hinge and camera cutouts in
/// `MediaQuery.displayFeatures` for [child], the way Flutter already reports
/// them on Android foldables.
///
/// Widgets that read display features then work unchanged: dialogs, bottom
/// sheets and menus (through `DisplayFeatureSubScreen`) open on one side of
/// the hinge instead of across it.
///
/// Place it above `MaterialApp` or `CupertinoApp`:
///
/// ```dart
/// runApp(const DuoDisplayFeatures(child: MyApp()));
/// ```
///
/// When the Flutter engine already reports display features, they are kept
/// as is. Elsewhere than on an iPhone Duo, [child] is returned untouched.
class DuoDisplayFeatures extends StatelessWidget {
  /// Creates the widget.
  const DuoDisplayFeatures({
    required this.child,
    this.includeCutouts = true,
    super.key,
  });

  /// The subtree that sees the display features.
  final Widget child;

  /// Whether active camera areas are reported as
  /// [DisplayFeatureType.cutout], in addition to the hinge.
  final bool includeCutouts;

  @override
  Widget build(BuildContext context) => GeometryDisplayFeatures(
    geometry: DuoDisplay.geometry,
    includeCutouts: includeCutouts,
    child: child,
  );
}

/// [DuoDisplayFeatures] with an injectable geometry stream.
@internal
class GeometryDisplayFeatures extends StatelessWidget {
  /// Creates the widget.
  const GeometryDisplayFeatures({
    required this.geometry,
    required this.includeCutouts,
    required this.child,
    super.key,
  });

  /// Settled geometry changes.
  final Stream<DuoGeometry> geometry;

  /// See [DuoDisplayFeatures.includeCutouts].
  final bool includeCutouts;

  /// See [DuoDisplayFeatures.child].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DuoGeometry>(
      stream: geometry,
      builder: (context, snapshot) {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery == null) return child;
        final geometry = snapshot.data;
        final features = geometry == null
            ? const <DisplayFeature>[]
            : displayFeaturesOf(geometry, includeCutouts: includeCutouts);
        final keep = features.isEmpty || mediaQuery.displayFeatures.isNotEmpty;
        // Always the same tree shape, with or without display features:
        // switching between `child` and a MediaQuery around it would tear
        // the whole app down and rebuild it, losing its state, on each fold.
        return MediaQuery(
          data: keep
              ? mediaQuery
              : mediaQuery.copyWith(displayFeatures: features),
          child: child,
        );
      },
    );
  }
}

/// The display features of [geometry]: the hinge band while the Flutter view
/// is on the inner screen, and, when [includeCutouts] is true, every active
/// camera area. Status columns are not display features: they stay available
/// in [DuoGeometry.statusColumns].
@internal
List<DisplayFeature> displayFeaturesOf(
  DuoGeometry geometry, {
  required bool includeCutouts,
}) => [
  if (geometry.hinge case final hinge?)
    DisplayFeature(
      bounds: hinge,
      type: DisplayFeatureType.hinge,
      state: switch (geometry.posture) {
        DuoPosture.book => DisplayFeatureState.postureHalfOpened,
        DuoPosture.open => DisplayFeatureState.postureFlat,
        DuoPosture.closed ||
        DuoPosture.unsupported => DisplayFeatureState.unknown,
      },
    ),
  if (includeCutouts)
    for (final cutout in geometry.cutouts)
      DisplayFeature(
        bounds: cutout,
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
];
