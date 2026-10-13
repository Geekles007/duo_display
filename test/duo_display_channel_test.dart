import 'dart:async';

import 'package:duo_display/duo_display.dart';
import 'package:duo_display/src/duo_display.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/probe_fixture.dart';

class _FakeHostApi extends DuoDisplayHostApi {
  _FakeHostApi({this.supported = true, this.snapshot});

  final bool supported;
  DuoGeometryMessage? snapshot;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<DuoGeometryMessage?> current() async => snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new listener first gets the current geometry', () async {
    final channel = DuoDisplayChannel(
      hostApi: _FakeHostApi(snapshot: probeFixture('closed')),
    );

    final first = await channel.geometry.first;

    expect(first.posture, DuoPosture.closed);
  });

  test('late listeners get the last geometry replayed', () async {
    final channel = DuoDisplayChannel(hostApi: _FakeHostApi())
      ..onGeometryChanged(probeFixture('open'));

    final early = await channel.geometry.first;
    final late = await channel.geometry.first;

    expect(early.posture, DuoPosture.open);
    expect(late, early);
  });

  test('changes reach every listener, without duplicates', () async {
    final channel = DuoDisplayChannel(hostApi: _FakeHostApi());
    final a = <DuoPosture>[];
    final b = <DuoPosture>[];
    final subscriptions = [
      channel.geometry.listen((geometry) => a.add(geometry.posture)),
      channel.geometry.listen((geometry) => b.add(geometry.posture)),
    ];

    channel
      ..onGeometryChanged(probeFixture('open'))
      ..onGeometryChanged(probeFixture('open'))
      ..onGeometryChanged(probeFixture('book'));
    await pumpEventQueue();

    expect(a, [DuoPosture.open, DuoPosture.book]);
    expect(b, a);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  });

  test('unsupported: no geometry and an empty stream', () async {
    final channel = DuoDisplayChannel(
      hostApi: _FakeHostApi(supported: false),
    );
    final received = <DuoGeometry>[];
    final subscription = channel.geometry.listen(received.add);

    expect(await channel.isSupported(), isFalse);
    expect(await channel.current(), isNull);
    await pumpEventQueue();
    expect(received, isEmpty);
    await subscription.cancel();
  });

  test(
    'without an iOS host, reports unsupported instead of throwing',
    () async {
      // No handler is registered on the test messenger, as on Android or web.
      final channel = DuoDisplayChannel();

      expect(await channel.isSupported(), isFalse);
      expect(await channel.current(), isNull);
      await expectLater(
        channel.geometry.timeout(const Duration(milliseconds: 50)).first,
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
