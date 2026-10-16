## 1.0.1

* Fix: on a flat iPhone Duo, dialogs, bottom sheets and menus stayed on one
  half of the screen. `DuoDisplayFeatures` no longer reports the fold while
  the device is flat: iOS marks it inactive, and Flutter treats any display
  feature of non-zero width as an obstacle, whatever its state.
* The fold is reported as `DisplayFeatureType.fold` instead of `hinge`: the
  inner display is one continuous panel, as on Android book-style foldables.
  Code that looks for `DisplayFeatureType.hinge` should also accept `fold`.
* `DuoLayoutBuilder(splitWhenFlat: true)` still splits a flat iPhone Duo:
  `DuoDisplayFeatures` hands it the fold directly, outside
  `MediaQuery.displayFeatures`. Its panes are unchanged.

## 1.0.0

* `DuoLayoutBuilder` hands its builder a `DuoLayout`: the two panes on either
  side of the hinge, in the builder's own coordinates, and `place()` to put a
  widget in each. It splits in Book, and when flat only with
  `splitWhenFlat: true`. It reads `MediaQuery.displayFeatures`, so it also
  splits on Android foldables.
* README rewritten: real simulator screenshots, a quick start, usage
  examples for every API, a posture table and a roadmap.
* The API is now stable and follows semantic versioning.

## 0.1.0

First release, for the iPhone Duo on iOS 27.1.

* `DuoDisplayFeatures` reports the hinge (`postureHalfOpened` in Book,
  `postureFlat` when open) and active camera cutouts in
  `MediaQuery.displayFeatures`, so dialogs, bottom sheets and menus open on
  one side of the hinge.
* `DuoDisplay.geometry`, `DuoDisplay.current()` and `DuoDisplay.isSupported`
  expose the raw geometry: posture, hinge angle, screen, hinge band, cutouts,
  status columns, vertical bars and split view.
* Requires Xcode 27.1 and an iOS deployment target of 15.0. Reports
  unsupported on other devices, older iOS versions and other platforms.
