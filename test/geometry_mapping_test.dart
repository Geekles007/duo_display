import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/probe_fixture.dart';

void main() {
  DuoGeometry fixture(String name) => geometryFromMessage(probeFixture(name));

  group('probe fixtures', () {
    test('closed: outer screen, camera inside the status column', () {
      final geometry = fixture('closed');

      expect(geometry.posture, DuoPosture.closed);
      expect(geometry.screen, DuoScreen.outer);
      expect(geometry.hingeAngle, 0);
      expect(geometry.hinge, isNull);
      expect(geometry.cutouts, [
        const Rect.fromLTWH(399.6666666666667, 29.333333333333332, 37, 37),
      ]);
      expect(geometry.statusColumns, [const Rect.fromLTWH(382, 0, 84, 170)]);
      expect(geometry.verticalBars, isTrue);
      expect(geometry.isSplitView, isFalse);
    });

    test('closed_landscape: the status column sits bottom right', () {
      final geometry = fixture('closed_landscape');

      expect(geometry.posture, DuoPosture.closed);
      expect(geometry.screen, DuoScreen.outer);
      expect(geometry.cutouts, [
        const Rect.fromLTWH(611.6666666666666, 399.6666666666667, 37, 37),
      ]);
      expect(geometry.statusColumns, [const Rect.fromLTWH(594, 384, 84, 82)]);
    });

    test('open: inner screen, inactive division, inactive inner camera', () {
      final geometry = fixture('open');

      expect(geometry.posture, DuoPosture.open);
      expect(geometry.screen, DuoScreen.inner);
      expect(geometry.hingeAngle, closeTo(180, 0.01));
      expect(geometry.hinge, const Rect.fromLTWH(455.5, 0, 40, 669));
      expect(geometry.cutouts, isEmpty);
      expect(geometry.statusColumns, [const Rect.fromLTWH(867, 0, 84, 120)]);
      expect(geometry.verticalBars, isTrue);
      expect(geometry.isSplitView, isFalse);
    });

    test('book: partially open with an active division', () {
      final geometry = fixture('book');

      expect(geometry.posture, DuoPosture.book);
      expect(geometry.screen, DuoScreen.inner);
      expect(geometry.hingeAngle, closeTo(127.5, 0.1));
      expect(geometry.hinge, const Rect.fromLTWH(455.5, 0, 40, 669));
    });

    test('book: the hinge status wins over a lagging inactive division', () {
      expect(fixture('book_division_inactive').posture, DuoPosture.book);
    });

    test('open_rotated: horizontal hinge band, horizontal status band', () {
      final geometry = fixture('open_rotated');

      expect(geometry.posture, DuoPosture.open);
      expect(geometry.screen, DuoScreen.inner);
      expect(geometry.hinge, const Rect.fromLTWH(0, 455.5, 669, 40));
      expect(geometry.cutouts, isEmpty);
      expect(geometry.statusColumns, [const Rect.fromLTWH(535, 0, 134, 82)]);
      expect(geometry.verticalBars, isFalse);
    });
  });

  group('without a hinge state yet', () {
    DuoGeometryMessage message({List<RegionMessage> regions = const []}) =>
        DuoGeometryMessage(
          viewSize: SizeMessage(width: 951, height: 669),
          windowSize: SizeMessage(width: 951, height: 669),
          screenSize: SizeMessage(width: 951, height: 669),
          verticalBarEdge: VerticalBarEdgeMessage.trailing,
          regions: regions,
        );

    RegionMessage division({required bool active}) => RegionMessage(
      kind: RegionKindMessage.division,
      active: active,
      frame: RectMessage(x: 455.5, y: 0, width: 40, height: 669),
    );

    test('an active division means book', () {
      final geometry = geometryFromMessage(
        message(regions: [division(active: true)]),
      );
      expect(geometry.posture, DuoPosture.book);
      expect(geometry.hingeAngle, isNull);
    });

    test('an inactive division means open', () {
      final geometry = geometryFromMessage(
        message(regions: [division(active: false)]),
      );
      expect(geometry.posture, DuoPosture.open);
    });

    test('occlusions without a division mean closed, on the outer screen', () {
      final geometry = geometryFromMessage(
        message(
          regions: [
            RegionMessage(
              kind: RegionKindMessage.occlusion,
              active: true,
              frame: RectMessage(x: 382, y: 0, width: 84, height: 170),
            ),
          ],
        ),
      );
      expect(geometry.posture, DuoPosture.closed);
      expect(geometry.screen, DuoScreen.outer);
    });

    test('no region at all is unsupported, on an unknown screen', () {
      final geometry = geometryFromMessage(message());
      expect(geometry.posture, DuoPosture.unsupported);
      expect(geometry.screen, DuoScreen.unknown);
    });
  });

  test('a window narrower than its screen is a split view', () {
    final geometry = geometryFromMessage(
      DuoGeometryMessage(
        viewSize: SizeMessage(width: 475, height: 669),
        windowSize: SizeMessage(width: 475, height: 669),
        screenSize: SizeMessage(width: 951, height: 669),
        verticalBarEdge: VerticalBarEdgeMessage.unspecified,
        regions: const [],
        hingeStatus: HingeStatusMessage.fullyOpen,
      ),
    );
    expect(geometry.isSplitView, isTrue);
  });
}
