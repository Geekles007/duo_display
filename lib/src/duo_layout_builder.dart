import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Lays out its subtree from the panes on either side of the hinge.
///
/// [builder] receives a [DuoLayout]: two panes when a half-opened hinge (or a
/// flat one, with [splitWhenFlat]) crosses this widget, a single one
/// otherwise. Its rectangles are relative to this widget, wherever it sits on
/// screen.
///
/// The hinge comes from `MediaQuery.displayFeatures`. On iOS, place
/// `DuoDisplayFeatures` above this widget; on Android foldables, Flutter
/// reports display features itself.
///
/// The widget measures where it sits after each frame. The very first frame
/// assumes the top left corner of the screen: when the widget sits elsewhere
/// and the hinge is horizontal, that frame splits at the wrong height and the
/// next one corrects it.
class DuoLayoutBuilder extends StatefulWidget {
  /// Creates the builder.
  const DuoLayoutBuilder({
    required this.builder,
    this.splitWhenFlat = false,
    super.key,
  });

  /// Builds the subtree from the current layout.
  final Widget Function(BuildContext context, DuoLayout layout) builder;

  /// Whether a flat hinge also splits the area. Defaults to false: when the
  /// device is flat, content may span the fold.
  final bool splitWhenFlat;

  @override
  State<DuoLayoutBuilder> createState() => _DuoLayoutBuilderState();
}

class _DuoLayoutBuilderState extends State<DuoLayoutBuilder> {
  /// A move smaller than this, in logical pixels, does not relayout.
  static const double _originTolerance = 0.5;

  /// Where this widget sat in the Flutter view at the last measurement.
  Offset _origin = Offset.zero;

  bool _measureScheduled = false;

  // The inputs and result of the last build, to tell whether a new origin
  // changes the panes.
  List<DisplayFeature> _displayFeatures = const [];
  Size _size = Size.zero;
  TextDirection _textDirection = TextDirection.ltr;
  DuoLayout? _layout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _displayFeatures = MediaQuery.displayFeaturesOf(context);
        _size = constraints.biggest;
        _textDirection = Directionality.of(context);
        final layout = _layout = _compute(_origin);
        _scheduleMeasure();
        return widget.builder(context, layout);
      },
    );
  }

  DuoLayout _compute(Offset origin) => computeDuoLayout(
    displayFeatures: _displayFeatures,
    area: origin & _size,
    textDirection: _textDirection,
    splitWhenFlat: widget.splitWhenFlat,
  );

  /// Measures after every frame while mounted, not only after this widget
  /// rebuilds: ancestors can move it (a page transition, a swipe in a
  /// `TabBarView`) without rebuilding it. A post-frame callback does not
  /// schedule frames, so this costs nothing while the screen is idle.
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      _measureOrigin();
      _scheduleMeasure();
    });
  }

  void _measureOrigin() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    if ((origin.dx - _origin.dx).abs() <= _originTolerance &&
        (origin.dy - _origin.dy).abs() <= _originTolerance) {
      return;
    }
    // Moving along the hinge (under an app bar in landscape, during a
    // vertical slide) leaves the panes unchanged: no need to rebuild.
    if (_compute(origin) == _layout) {
      _origin = origin;
    } else {
      setState(() => _origin = origin);
    }
  }
}

/// The panes on either side of the hinge, in logical pixels, relative to the
/// top left corner of a [DuoLayoutBuilder].
@immutable
final class DuoLayout {
  const DuoLayout._single(this.first)
    : axis = null,
      second = null,
      hinge = null;

  const DuoLayout._split({
    required Axis this.axis,
    required this.first,
    required Rect this.second,
    required Rect this.hinge,
  });

  /// [Axis.horizontal] when the panes sit side by side (vertical hinge),
  /// [Axis.vertical] when they are stacked (horizontal hinge), null when not
  /// split.
  final Axis? axis;

  /// The leading pane: left (right in right-to-left text) or top. When not
  /// split, the whole area.
  final Rect first;

  /// The trailing pane, or null when not split.
  final Rect? second;

  /// The hinge band, clipped to the area, or null when not split.
  final Rect? hinge;

  /// Whether the area is split in two around the hinge.
  bool get isSplit => second != null;

  /// Places [first] and [second] in their panes and leaves the hinge empty.
  /// When not split, shows [first] over the whole area and never builds
  /// [second].
  Widget place({required Widget first, required Widget second}) {
    // Unbounded constraints leave no area to position panes in.
    if (!this.first.isFinite) return first;
    final secondPane = this.second;
    // The same tree shape whether split or not, so that [first] keeps its
    // state (scroll position, focus, controllers) when the split changes.
    return Stack(
      children: [
        Positioned.fromRect(rect: this.first, child: first),
        if (secondPane != null)
          Positioned.fromRect(rect: secondPane, child: second),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoLayout &&
      other.axis == axis &&
      other.first == first &&
      other.second == second &&
      other.hinge == hinge;

  @override
  int get hashCode => Object.hash(axis, first, second, hinge);

  @override
  String toString() =>
      'DuoLayout(axis: $axis, first: $first, second: $second, hinge: $hinge)';
}

/// Splits [area], the builder's rectangle in the Flutter view's coordinates,
/// around the first display feature that separates it.
///
/// A hinge or fold separates the area when it is half opened, or flat with
/// [splitWhenFlat], and when it crosses the area entirely while leaving room
/// on both sides. A feature taller than wide puts the panes side by side,
/// any other one stacks them.
@internal
DuoLayout computeDuoLayout({
  required List<DisplayFeature> displayFeatures,
  required Rect area,
  required TextDirection textDirection,
  required bool splitWhenFlat,
}) {
  final whole = Offset.zero & area.size;
  if (!area.isFinite) return DuoLayout._single(whole);

  for (final feature in displayFeatures) {
    final bounds = feature.bounds;
    if (!_separates(feature, splitWhenFlat: splitWhenFlat) ||
        (bounds.width == 0 && bounds.height == 0)) {
      continue;
    }
    final vertical = bounds.height > bounds.width;
    if (!_crosses(bounds, area, vertical: vertical)) continue;

    final local = bounds.shift(-area.topLeft);
    if (vertical) {
      final start = Rect.fromLTRB(0, 0, local.left, area.height);
      final end = Rect.fromLTRB(local.right, 0, area.width, area.height);
      final leftToRight = textDirection == TextDirection.ltr;
      return DuoLayout._split(
        axis: Axis.horizontal,
        first: leftToRight ? start : end,
        second: leftToRight ? end : start,
        hinge: Rect.fromLTRB(local.left, 0, local.right, area.height),
      );
    }
    return DuoLayout._split(
      axis: Axis.vertical,
      first: Rect.fromLTRB(0, 0, area.width, local.top),
      second: Rect.fromLTRB(0, local.bottom, area.width, area.height),
      hinge: Rect.fromLTRB(0, local.top, area.width, local.bottom),
    );
  }
  return DuoLayout._single(whole);
}

bool _separates(DisplayFeature feature, {required bool splitWhenFlat}) {
  if (feature.type != DisplayFeatureType.hinge &&
      feature.type != DisplayFeatureType.fold) {
    return false;
  }
  return switch (feature.state) {
    DisplayFeatureState.postureHalfOpened => true,
    DisplayFeatureState.postureFlat => splitWhenFlat,
    DisplayFeatureState.unknown => false,
  };
}

/// Whether [bounds] crosses [area] entirely along the hinge and leaves room
/// on both sides of it, as in `DisplayFeatureSubScreen`.
bool _crosses(Rect bounds, Rect area, {required bool vertical}) => vertical
    ? bounds.top <= area.top &&
          bounds.bottom >= area.bottom &&
          bounds.left > area.left &&
          bounds.right < area.right
    : bounds.left <= area.left &&
          bounds.right >= area.right &&
          bounds.top > area.top &&
          bounds.bottom < area.bottom;
