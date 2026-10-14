# DuoLayoutBuilder design

- Date: 2026-10-14
- Target: duo_display 1.0.0 (planned 2026-11-09)
- Branch: `feat/duo-layout-builder`

## Goal

0.1.0 reports the iPhone Duo hinge in `MediaQuery.displayFeatures`, which
makes dialogs, bottom sheets and menus avoid it. An app's own screens still
render across the fold. `DuoLayoutBuilder` gives developers the two areas on
either side of the hinge, already computed in their own coordinates, so a
list and detail screen can put one pane on each side.

1.0.0 contains `DuoLayoutBuilder` and nothing else. It also commits the 0.1.0
API to semantic versioning as it stands: no API review is planned.

## Decisions

| Topic | Decision |
| --- | --- |
| Role | A builder that computes the panes. The developer decides what goes in them. No ready-made two-pane widget. |
| When to split | In Book (half opened). When flat, only with `splitWhenFlat: true`. Never when closed. |
| Source of truth | `MediaQuery.displayFeatures`, so the same code also splits on Android foldables. On iOS this requires `DuoDisplayFeatures` above the builder. |
| Coordinates | Panes are in the builder's own coordinates, corrected for where the builder sits on screen (under an app bar, for instance). |

## Public API

Exported from `package:duo_display/duo_display.dart`:

```dart
class DuoLayoutBuilder extends StatefulWidget {
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
}

@immutable
class DuoLayout {
  /// Whether the area is split in two around the hinge.
  bool get isSplit;

  /// Axis.horizontal when the panes sit side by side (vertical hinge),
  /// Axis.vertical when they are stacked (horizontal hinge), null when not
  /// split.
  final Axis? axis;

  /// The leading pane: left (right in right-to-left text) or top. When not
  /// split, the whole area.
  final Rect first;

  /// The trailing pane, or null when not split.
  final Rect? second;

  /// The hinge band, clipped to the area, or null when not split.
  final Rect? hinge;

  /// Places [first] and [second] in their panes and leaves the hinge empty.
  /// When not split, shows [first] over the whole area and never builds
  /// [second].
  Widget place({required Widget first, required Widget second});
}
```

All rectangles are in logical pixels, relative to the builder's top left
corner. `DuoLayout` implements `==`, `hashCode` and `toString`.

Not in the API, on purpose:

- No posture in `DuoLayout`. The builder only reads display features so that
  it stays valid on Android. The iPhone posture is in `DuoDisplay.geometry`.
- No options on `place()` (proportions, padding, animation). Developers who
  need more lay out `first` and `second` themselves.

## Splitting rules

Inputs: `MediaQuery.displayFeatures` (in the Flutter view's coordinates), the
builder's area in the same coordinates (its measured origin and its size),
the ambient `TextDirection`, and `splitWhenFlat`.

1. **Candidates.** Display features of type `hinge` or `fold`. Cutouts and
   `unknown` types are ignored.
2. **Separating state.** `postureHalfOpened` splits. `postureFlat` splits only
   with `splitWhenFlat`. `unknown` never splits (closed, or in transition).
3. **Orientation.** A feature whose height exceeds its width is vertical:
   panes sit side by side. Any other feature is horizontal: panes are
   stacked. A feature with zero width and zero height is ignored.
4. **Coverage.** The feature splits the area only if it crosses it entirely
   and leaves room on both sides. For a vertical feature:
   `feature.top <= area.top`, `feature.bottom >= area.bottom`,
   `feature.left > area.left` and `feature.right < area.right`. The same
   rule, transposed, applies to a horizontal feature. This matches
   `DisplayFeatureSubScreen`.
5. **First match.** When several features qualify, the first in
   `displayFeatures` order wins.
6. **Panes.** For a vertical feature, translated into the builder's
   coordinates: the start pane runs from the area's left edge to the
   feature's left edge, the end pane from the feature's right edge to the
   area's right edge, and `hinge` is the feature clipped to the area. With
   left-to-right text, `first` is the start pane; with right-to-left text,
   `first` is the end pane. For a horizontal feature, `first` is the top pane
   and `second` the bottom one, whatever the text direction.

Edge cases:

- No display features (another device, or `DuoDisplayFeatures` missing on
  iOS): not split. This is documented; it cannot be detected reliably.
- Unbounded constraints (inside a scroll view): not split. `first` is
  `Offset.zero & constraints.biggest`, which may be infinite, and `place()`
  returns the `first` widget unsized.
- No minimum pane size: rule 4 already rejects a hinge at the very edge.

Expected results on the iPhone Duo (measured geometry):

| Pose | Result |
| --- | --- |
| Closed | Not split: the outer screen has no hinge. |
| Book, landscape 951x669 | Side by side, 455.5 pt each, 40 pt hinge band. |
| Book, portrait 669x951 under an app bar | Stacked, split at the fold's real height. |
| Flat | Not split, or side by side / stacked with `splitWhenFlat`. |

## Position tracking

`DuoLayoutBuilder` is stateful and keeps its last measured origin in the
Flutter view, starting at `Offset.zero`.

1. `build` returns a `LayoutBuilder`. Its callback takes the size from the
   constraints and the origin from the state, computes the `DuoLayout` and
   calls `builder`.
2. After every frame while mounted, a post-frame callback reads the actual
   origin with `RenderBox.localToGlobal(Offset.zero)` on the builder's render
   box, then re-arms itself. If the origin differs from the stored one by
   more than 0.5 pt, `setState` stores it and the layout is recomputed.
   Measuring only after the builder's own rebuilds is not enough: ancestors
   move it without rebuilding it (page transitions, `TabBarView` swipes).
3. Dependencies: `MediaQuery.displayFeaturesOf` (only that aspect),
   `Directionality.of`, the constraints, and the measured origin. A
   post-frame callback does not schedule frames, so the measurement costs
   nothing while the screen is idle and cannot loop.

`localToGlobal` only asserts that the render object is attached, so reading
it after the frame is safe. The post-frame callback does nothing once the
state is unmounted.

Trade-offs, documented in the README:

- The very first frame uses `Offset.zero`. When the builder is not at the
  origin and the hinge is horizontal (portrait under an app bar), that one
  frame splits at the wrong height, then the next frame is correct. In
  landscape the hinge is vertical and a vertical offset changes nothing.
- During page transitions and swipes the builder rebuilds whenever it moves
  by more than 0.5 pt: extra rebuilds while it moves, correct at the end.
- Ancestor rotation or scaling is not compensated; only the origin is.
- Scrolling lists give unbounded constraints along their axis, which never
  split. `PageView` and `TabBarView` pages are bounded and split.

Rejected: a custom render object that re-checks its position on every paint.
It has the same first-frame limitation for much more code.

## Code layout

- `lib/src/duo_layout_builder.dart`: `DuoLayoutBuilder`, `DuoLayout`, and an
  `@internal` pure function `computeDuoLayout({displayFeatures, area,
  textDirection, splitWhenFlat})` that implements the splitting rules.
- `lib/duo_display.dart` exports `DuoLayoutBuilder` and `DuoLayout`.

## Testing

Unit tests on `computeDuoLayout`, table driven. iPhone cases chain the real
probe fixtures through `geometryFromMessage` and `displayFeaturesOf`:

- Book, landscape (`book.json`): side by side, panes and hinge as measured.
- Flat (`open.json`): not split; split with `splitWhenFlat`.
- Flat, portrait (`open_rotated.json`) with `splitWhenFlat`: stacked.
- Closed (`closed.json`): not split; the camera cutout is ignored.
- Right-to-left text: `first` and `second` swap for side by side panes only.
- Feature outside the area, `unknown` state, Android-like zero-width fold,
  unbounded constraints.

Widget tests:

- Book, portrait, under a `Scaffold` with an `AppBar` (synthetic display
  features, no real fixture covers this pose): after the correction frame,
  the second pane starts at the fold's real bottom edge in global
  coordinates; on the very first frame it does not.
- No display features: one pane, and the `second` builder is never called.
- `place()` leaves the hinge band empty.

Optional: capture a Book portrait fixture with the probe during the
simulator checkpoint.

## Example app

The list page uses `DuoLayoutBuilder`:

- Split: the list in `first`, the selected item's detail in `second`, no
  navigation.
- Not split: unchanged, tapping an item pushes the detail page.
- A switch in the app bar toggles `splitWhenFlat`.

## Documentation and release

- README: a "Two panes around the hinge" section with an example, the results
  table and the position tracking trade-offs.
- CHANGELOG 1.0.0; version 1.0.0 in `pubspec.yaml` and the podspec.
- `main` stays on the 0.1.0 commit until 0.1.0 is published (2026-10-26).
  The feature branch is pushed only with the maintainer's approval.

## Checkpoints

1. `computeDuoLayout`, `DuoLayoutBuilder` and their tests: analyze and tests
   green.
2. Example app on the `Duo-27.1` simulator, poses set by the maintainer in
   Device Hub: split in Book, single pane when closed, `splitWhenFlat`
   working when flat.
