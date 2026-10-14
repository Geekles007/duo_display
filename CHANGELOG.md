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
