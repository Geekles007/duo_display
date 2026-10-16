import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:duo_display/src/duo_display.dart';
import 'package:duo_display/src/duo_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Reports the iPhone Duo fold and camera cutouts in
/// `MediaQuery.displayFeatures` for [child], the way Flutter already reports
/// them on Android foldables.
///
/// Widgets that read display features then work unchanged: in Book posture,
/// dialogs, bottom sheets and menus (through `DisplayFeatureSubScreen`) open
/// on one side of the fold instead of across it. When the device is flat the
/// fold is not reported, so they can span the whole screen; it is still
/// handed to `DuoLayoutBuilder` for `splitWhenFlat`.
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
  /// [DisplayFeatureType.cutout], in addition to the fold.
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
          child: FlatFoldScope(
            fold: geometry == null ? null : flatFoldOf(geometry),
            child: child,
          ),
        );
      },
    );
  }
}

/// The display features of [geometry]: the fold while the device is in Book
/// posture, and, when [includeCutouts] is true, every active camera area.
/// Status columns are not display features: they stay available in
/// [DuoGeometry.statusColumns].
///
/// The band is a [DisplayFeatureType.fold], not a hinge: the inner display is
/// one continuous panel, as on Android book-style foldables. It is left out
/// while the device is flat: iOS then marks it inactive, and Flutter treats
/// any feature of non-zero width as an obstacle whatever its state
/// (`DisplayFeatureSubScreen.avoidBounds`), so reporting it would keep
/// dialogs on one half of a flat screen.
@internal
List<DisplayFeature> displayFeaturesOf(
  DuoGeometry geometry, {
  required bool includeCutouts,
}) => [
  if ((geometry.posture, geometry.hinge) case (DuoPosture.book, final hinge?))
    DisplayFeature(
      bounds: hinge,
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    ),
  if (includeCutouts)
    for (final cutout in geometry.cutouts)
      DisplayFeature(
        bounds: cutout,
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
];

/// The fold of a flat device, or null in any other posture. It never reaches
/// `MediaQuery.displayFeatures` (see [displayFeaturesOf]); it only lets
/// `DuoLayoutBuilder` split a flat device when asked to.
@internal
DisplayFeature? flatFoldOf(DuoGeometry geometry) =>
    switch ((geometry.posture, geometry.hinge)) {
      (DuoPosture.open, final hinge?) => DisplayFeature(
        bounds: hinge,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      ),
      _ => null,
    };

/// Hands the fold of a flat device to `DuoLayoutBuilder` without exposing it
/// to the rest of Flutter.
@internal
class FlatFoldScope extends InheritedWidget {
  /// Creates the scope.
  const FlatFoldScope({required this.fold, required super.child, super.key});

  /// The fold of a flat device, or null.
  final DisplayFeature? fold;

  /// The nearest flat fold above [context], or null.
  static DisplayFeature? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlatFoldScope>()?.fold;

  @override
  bool updateShouldNotify(FlatFoldScope oldWidget) => fold != oldWidget.fold;
}
