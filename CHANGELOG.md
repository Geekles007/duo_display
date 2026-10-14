## 1.0.0

* `DuoLayoutBuilder` hands its builder a `DuoLayout`: the two panes on either
  side of the hinge, in the builder's own coordinates, and `place()` to put a
  widget in each. It splits in Book, and when flat only with
  `splitWhenFlat: true`. It reads `MediaQuery.displayFeatures`, so it also
  splits on Android foldables.
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
