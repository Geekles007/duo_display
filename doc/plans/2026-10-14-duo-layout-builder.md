# DuoLayoutBuilder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `DuoLayoutBuilder`, a builder that hands developers the two panes on either side of the iPhone Duo hinge in their own coordinates, as duo_display 1.0.0.

**Architecture:** A pure function turns `MediaQuery.displayFeatures`, the builder's area in the Flutter view and the text direction into an immutable `DuoLayout`. A stateful widget feeds it with its size (from a `LayoutBuilder`) and its origin (measured after each frame with `localToGlobal`, corrected with `setState` when it moves). Pure Dart: no native or Pigeon change.

**Tech Stack:** Flutter ≥ 3.44, Dart ^3.12.2, flutter_test, very_good_analysis.

**Spec:** `doc/specs/2026-10-14-duo-layout-builder-design.md`

## Global Constraints

- Work on branch `feat/duo-layout-builder`. Never touch `main`. Never push without the maintainer's approval.
- Public names exactly as in the spec: `DuoLayoutBuilder({required builder, splitWhenFlat = false})`, `DuoLayout` with `isSplit`, `axis`, `first`, `second`, `hinge`, `place({required first, required second})`.
- Rectangles are in logical pixels, relative to the builder's top left corner.
- Origin tolerance: a measured origin that differs by more than 0.5 pt triggers a correction; 0.5 pt or less does not.
- `flutter analyze` clean under very_good_analysis; `dart format` every changed file except `lib/src/messages.g.dart`.
- Code, comments and commit messages in English, conventional commits, no AI attribution in commits.
- Commands run from the repository root, `/Users/geekles/projects/duo_display`.

## Review Focus

Inputs the spec implies but its listed tests do not exercise, each pinned by a test in Task 2:

1. Pose change while the builder stays mounted (Book → flat → closed): the layout must follow without a remount.
2. `splitWhenFlat` toggled at runtime on a flat hinge: the split must appear and disappear immediately.
3. Text direction flipped at runtime: side-by-side panes must swap without a remount.
4. The builder's own size changing (rotation from landscape to portrait) with matching display features: panes must switch from side by side to stacked.
5. A builder sitting at the view's origin: the very first frame must already be correct (no flash).

---

### Task 1: `DuoLayout` and `computeDuoLayout`

**Files:**
- Create: `lib/src/duo_layout_builder.dart`
- Test: `test/duo_layout_test.dart`

**Interfaces:**
- Consumes: `displayFeaturesOf(DuoGeometry, {required bool includeCutouts})` from `lib/src/duo_display_features.dart`, `geometryFromMessage(DuoGeometryMessage)` from `lib/src/geometry_mapping.dart`, `probeFixture(String)` from `test/helpers/probe_fixture.dart` (tests only).
- Produces:
  - `@immutable class DuoLayout` with `final Axis? axis`, `final Rect first`, `final Rect? second`, `final Rect? hinge`, `bool get isSplit` (true when `second != null`), `==`, `hashCode`, `toString`. Private constructors only (for example `DuoLayout._single(Rect area)` and `DuoLayout._split({required Axis axis, required Rect first, required Rect second, required Rect hinge})`). `place` is added in Task 2.
  - `@internal DuoLayout computeDuoLayout({required List<DisplayFeature> displayFeatures, required Rect area, required TextDirection textDirection, required bool splitWhenFlat})`, where `area` is the builder's rectangle in the Flutter view's coordinates.

- [ ] **Step 1: Write the failing tests**

Helpers in the test file:

```dart
List<DisplayFeature> features(String fixture) => displayFeaturesOf(
  geometryFromMessage(probeFixture(fixture)),
  includeCutouts: true,
);

DuoLayout compute(
  List<DisplayFeature> displayFeatures, {
  Rect area = const Rect.fromLTWH(0, 0, 951, 669),
  TextDirection textDirection = TextDirection.ltr,
  bool splitWhenFlat = false,
}) => computeDuoLayout(
  displayFeatures: displayFeatures,
  area: area,
  textDirection: textDirection,
  splitWhenFlat: splitWhenFlat,
);
```

Tests and their assertions:

- `book splits side by side around the measured hinge`: `compute(features('book'))` has `isSplit` true, `axis == Axis.horizontal`, `first == Rect.fromLTRB(0, 0, 455.5, 669)`, `second == Rect.fromLTRB(495.5, 0, 951, 669)`, `hinge == Rect.fromLTRB(455.5, 0, 495.5, 669)`.
- `book with a lagging division still splits`: `compute(features('book_division_inactive')).isSplit` is true.
- `flat does not split by default`: `compute(features('open'))` has `isSplit` false, `axis`, `second` and `hinge` null, `first == Rect.fromLTWH(0, 0, 951, 669)`.
- `flat splits with splitWhenFlat`: `compute(features('open'), splitWhenFlat: true)` equals the Book result's `first`, `second` and `hinge`.
- `flat portrait stacks with splitWhenFlat`: `compute(features('open_rotated'), area: Rect.fromLTWH(0, 0, 669, 951), splitWhenFlat: true)` has `axis == Axis.vertical`, `first == Rect.fromLTRB(0, 0, 669, 455.5)`, `second == Rect.fromLTRB(0, 495.5, 669, 951)`.
- `closed does not split and ignores the camera cutout`: `compute(features('closed'), area: Rect.fromLTWH(0, 0, 466, 678)).isSplit` is false.
- `right-to-left swaps side by side panes`: with `textDirection: TextDirection.rtl` on `features('book')`, `first == Rect.fromLTRB(495.5, 0, 951, 669)` and `second == Rect.fromLTRB(0, 0, 455.5, 669)`.
- `right-to-left keeps stacked panes top first`: RTL on the `open_rotated` case above gives the same `first` and `second` as LTR.
- `coordinates are relative to the area`: `compute(features('book'), area: Rect.fromLTWH(0, 56, 951, 613))` gives `first == Rect.fromLTRB(0, 0, 455.5, 613)` and `hinge == Rect.fromLTRB(455.5, 0, 495.5, 613)`.
- `a hinge outside the area does not split`: `compute(features('book'), area: Rect.fromLTWH(0, 0, 455.5, 669)).isSplit` is false.
- `an unknown state does not split`: a `DisplayFeature(bounds: Rect.fromLTWH(455.5, 0, 40, 669), type: DisplayFeatureType.hinge, state: DisplayFeatureState.unknown)` gives `isSplit` false.
- `an Android zero-width fold splits side by side`: `DisplayFeature(bounds: Rect.fromLTWH(475, 0, 0, 669), type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened)` gives `first == Rect.fromLTRB(0, 0, 475, 669)`, `second == Rect.fromLTRB(475, 0, 951, 669)`, `hinge` with zero width.
- `a zero-size feature is ignored`: a half-opened fold with `Rect.fromLTWH(475, 300, 0, 0)` gives `isSplit` false.
- `an unknown feature type is ignored`: `DisplayFeature(bounds: Rect.fromLTWH(455.5, 0, 40, 669), type: DisplayFeatureType.unknown, state: DisplayFeatureState.postureHalfOpened)` gives `isSplit` false.
- `the first qualifying feature wins`: a half-opened fold at `Rect.fromLTWH(300, 0, 0, 669)` listed before `features('book')` gives `first == Rect.fromLTRB(0, 0, 300, 669)`.
- `unbounded constraints do not split`: `area: Rect.fromLTWH(0, 0, 951, double.infinity)` with `features('book')` gives `isSplit` false and `first.height == double.infinity`.
- `equal layouts are equal`: two `compute(features('book'))` results are `==` and share a `hashCode`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/duo_layout_test.dart`
Expected: compilation failure, `computeDuoLayout` and `DuoLayout` are undefined.

- [ ] **Step 3: Implement `DuoLayout` and `computeDuoLayout` in `lib/src/duo_layout_builder.dart`**

Follow the spec's splitting rules 1 to 6 in order. If `area` is not finite, return `DuoLayout._single(Offset.zero & area.size)`. Translate the chosen feature by `-area.topLeft` before cutting the panes, and clip `hinge` to the area. Dartdoc on every public member, copied from the spec's API block.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/duo_layout_test.dart`
Expected: all tests pass. Then `flutter analyze` reports no issues.

- [ ] **Step 5: Commit**

```bash
dart format lib/src/duo_layout_builder.dart test/duo_layout_test.dart
git add lib/src/duo_layout_builder.dart test/duo_layout_test.dart
git commit -m "feat: compute the panes around the hinge from display features"
```

### Task 2: `DuoLayout.place` and `DuoLayoutBuilder`

**Files:**
- Modify: `lib/src/duo_layout_builder.dart`
- Modify: `lib/duo_display.dart` (export)
- Test: `test/duo_layout_builder_test.dart`

**Interfaces:**
- Consumes: `DuoLayout` and `computeDuoLayout` from Task 1.
- Produces:
  - `Widget DuoLayout.place({required Widget first, required Widget second})`.
  - `class DuoLayoutBuilder extends StatefulWidget` with `const DuoLayoutBuilder({required Widget Function(BuildContext context, DuoLayout layout) builder, bool splitWhenFlat = false, super.key})`.
  - `lib/duo_display.dart` adds `export 'src/duo_layout_builder.dart' show DuoLayout, DuoLayoutBuilder;`.

- [ ] **Step 1: Write the failing tests**

Shared setup: set `tester.view.physicalSize` and `tester.view.devicePixelRatio = 1`, reset in `addTearDown(tester.view.reset)`. Wrap the tree in `MediaQuery(data: MediaQueryData(size: <view size>, displayFeatures: <features>), child: Directionality(...) or MaterialApp(...))`. Put `Container(key: firstKey)` and `Container(key: secondKey)` in `layout.place(...)` and assert with `tester.getRect`. Synthetic portrait Book hinge: `DisplayFeature(bounds: Rect.fromLTWH(0, 455.5, 669, 40), type: DisplayFeatureType.hinge, state: DisplayFeatureState.postureHalfOpened)`.

Tests and their assertions:

- `place puts the panes on either side of the hinge`: 951×669 view, `book` fixture features (via `displayFeaturesOf`/`geometryFromMessage`/`probeFixture`), builder at the root. `getRect(firstKey) == Rect.fromLTRB(0, 0, 455.5, 669)`, `getRect(secondKey) == Rect.fromLTRB(495.5, 0, 951, 669)`.
- `not split: only first is built`: no display features. `getRect(firstKey) == Rect.fromLTWH(0, 0, 951, 669)`, `find.byKey(secondKey)` finds nothing, and a counter incremented in a `Builder` used as `second` stays at 0.
- `corrects its position under an app bar`: 669×951 view, synthetic portrait Book hinge, `MaterialApp(home: Scaffold(appBar: AppBar(), body: DuoLayoutBuilder(...)))`. After `pumpWidget`, `getRect(secondKey).top` is not 495.5 (first frame uses origin zero). After one more `pump()`, `getRect(firstKey).bottom == 455.5` and `getRect(secondKey).top == 495.5` in global coordinates.
- `correct on the first frame at the origin` (Review Focus 5): 951×669 view, `book` features, builder at the root. Right after `pumpWidget`, without a further pump, `getRect(secondKey).left == 495.5`.
- `follows pose changes while mounted` (Review Focus 1): same widget with features from `book`, then `open`, then `closed`, re-pumped with the same keys. `isSplit` observed in the builder goes true, false, false; `find.byKey(secondKey)` disappears after `open`.
- `splitWhenFlat toggles at runtime` (Review Focus 2): `open` features; pump with `splitWhenFlat: false` (one pane), then `true` (`getRect(secondKey).left == 495.5`), then `false` again (one pane).
- `swaps panes when the text direction flips` (Review Focus 3): `book` features under `Directionality(textDirection: ltr)` then `rtl`. In RTL, `getRect(firstKey).left == 495.5`.
- `restacks when the view rotates` (Review Focus 4): 951×669 with `book` features, then view 669×951 with the synthetic portrait hinge. After the rotation, `getRect(firstKey) == Rect.fromLTRB(0, 0, 669, 455.5)`.
- `with DuoDisplayFeatures above, splits from the host geometry`: mock `dev.flutter.pigeon.duo_display.DuoDisplayHostApi.current` to return `probeFixture('book')` (same pattern as `test/duo_display_features_test.dart`), tree `DuoDisplayFeatures(child: Directionality(textDirection: TextDirection.ltr, child: DuoLayoutBuilder(...)))` on a 951×669 view. After `pumpAndSettle`, `getRect(secondKey).left == 495.5`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/duo_layout_builder_test.dart`
Expected: compilation failure, `DuoLayoutBuilder` and `place` are undefined.

- [ ] **Step 3: Implement `place` and `DuoLayoutBuilder`**

- `place`: when not split, return `first` as is; when split, a `Stack` with two `Positioned.fromRect` children at `this.first` and `this.second`.
- `DuoLayoutBuilder` state keeps `Offset _origin = Offset.zero`. `build` returns a `LayoutBuilder` whose callback calls `computeDuoLayout` with `MediaQuery.displayFeaturesOf(context)`, `_origin & constraints.biggest`, `Directionality.of(context)` and `widget.splitWhenFlat`, schedules a post-frame callback, and returns `widget.builder(context, layout)`.
- The post-frame callback returns if `!mounted`; otherwise it reads `(context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero)` and calls `setState` only when that origin differs from `_origin` by more than 0.5 pt in either axis.
- Dartdoc on `DuoLayoutBuilder` states the iOS requirement (`DuoDisplayFeatures` above it) and the first-frame trade-off.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test`
Expected: every test passes (the 25 existing ones plus Tasks 1 and 2). Then `flutter analyze` reports no issues.

- [ ] **Step 5: Commit**

```bash
dart format lib/src/duo_layout_builder.dart lib/duo_display.dart test/duo_layout_builder_test.dart
git add lib/src/duo_layout_builder.dart lib/duo_display.dart test/duo_layout_builder_test.dart
git commit -m "feat: add DuoLayoutBuilder to lay out two panes around the hinge"
```

**Checkpoint 1:** stop and report to the maintainer: analyze and test output, the public API as exported.

### Task 3: List and detail in the example app

**Files:**
- Modify: `example/lib/main.dart`

**Interfaces:**
- Consumes: `DuoLayoutBuilder`, `DuoLayout.place` and `DuoLayout.isSplit` from Task 2; existing `ItemDetailPage`, `showExampleDialog`, `GeometryOverlay`.
- Produces: nothing used by later tasks.

- [ ] **Step 1: Turn `ItemListPage` into a `StatefulWidget`**

State: `int _selected = 0` and `bool _splitWhenFlat = false`. The app bar gets a `Switch` (with a "Split when flat" tooltip or label) bound to `_splitWhenFlat`. The body is `DuoLayoutBuilder(splitWhenFlat: _splitWhenFlat, builder: (context, layout) => layout.place(first: <the list>, second: ItemDetailView(index: _selected)))`. A tap on an item selects it when `layout.isSplit`, and pushes `ItemDetailPage` otherwise. Keep the "Dialog" floating action button.

- [ ] **Step 2: Extract `ItemDetailView`**

Move the detail page's body (title, posture text, dialog and bottom sheet buttons) into `class ItemDetailView extends StatelessWidget` with `const ItemDetailView({required int index})`. `ItemDetailPage` becomes a `Scaffold` whose body is `ItemDetailView`.

- [ ] **Step 3: Verify**

Run: `dart format example/lib && flutter analyze && (cd example && flutter build ios --simulator)`
Expected: no analyzer issues, and the build ends with `✓ Built build/ios/iphonesimulator/Runner.app`.

- [ ] **Step 4: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat(example): show list and detail side by side with DuoLayoutBuilder"
```

**Checkpoint 2:** run `cd example && flutter run -d Duo-27.1`. The maintainer sets poses in Device Hub. Expected: Book shows the list in one pane and the detail in the other, with the hinge band between them; Closed shows the list only; flat shows one pane, and two once the switch is on. Optionally capture a Book portrait fixture with `tool/probe/run.sh` and `tool/probe/snap.sh book_rotated`.

### Task 4: Documentation and version 1.0.0

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `pubspec.yaml`, `ios/duo_display.podspec`

**Interfaces:**
- Consumes: the API from Task 2.
- Produces: the 1.0.0 release candidate.

- [ ] **Step 1: README**

Add a "Two panes around the hinge" section after "Raw geometry": a `DuoLayoutBuilder` example using `place`, the spec's results table, the `DuoDisplayFeatures` requirement on iOS, and the position tracking trade-offs (first frame, transitions, ancestor transforms, scroll views). Remove the "A layout helper is planned for 1.0" limitation.

- [ ] **Step 2: CHANGELOG and versions**

Add a `## 1.0.0` entry above `## 0.1.0`: `DuoLayoutBuilder` and `DuoLayout`, splitting rules in one line, and "The API is now stable and follows semantic versioning." Set `version: 1.0.0` in `pubspec.yaml` and `s.version = '1.0.0'` in the podspec.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test && dart pub publish --dry-run`
Expected: no analyzer issues, all tests pass, and the dry run ends with `Package has 0 warnings.` (commit first if it warns about uncommitted files, then re-run).

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md pubspec.yaml ios/duo_display.podspec
git commit -m "docs: document DuoLayoutBuilder and prepare 1.0.0"
```
