import 'dart:async';

import 'package:duo_display/src/duo_geometry.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Access to the iPhone Duo display geometry.
///
/// iOS only. On other platforms, below iOS 27.1 and on devices without a
/// hinge, [isSupported] completes with false, [current] with null, and
/// [geometry] emits nothing.
///
/// Requires an initialized Flutter binding: use it from widgets, or call
/// `WidgetsFlutterBinding.ensureInitialized()` first.
abstract final class DuoDisplay {
  static final DuoDisplayChannel _channel = DuoDisplayChannel();

  /// Settled geometry changes.
  ///
  /// A broadcast stream: each new listener first receives the last known
  /// geometry, if any, then every change.
  static Stream<DuoGeometry> get geometry => _channel.geometry;

  /// The current geometry, or null when unsupported or not known yet.
  static Future<DuoGeometry?> current() => _channel.current();

  /// Whether this device exposes foldable geometry.
  static Future<bool> get isSupported => _channel.isSupported();
}

/// Turns the Pigeon APIs into the streams and futures of [DuoDisplay].
@internal
class DuoDisplayChannel implements DuoDisplayFlutterApi {
  /// Creates a channel. Tests inject a fake [hostApi].
  DuoDisplayChannel({
    DuoDisplayHostApi? hostApi,
    BinaryMessenger? binaryMessenger,
  }) : _hostApi =
           hostApi ?? DuoDisplayHostApi(binaryMessenger: binaryMessenger),
       _binaryMessenger = binaryMessenger;

  /// Pigeon's error code when no host handles the channel, which is the case
  /// on every platform but iOS.
  static const _channelError = 'channel-error';

  final DuoDisplayHostApi _hostApi;
  final BinaryMessenger? _binaryMessenger;
  final StreamController<DuoGeometry> _changes = StreamController.broadcast();
  DuoGeometry? _last;
  bool _receiving = false;

  /// See [DuoDisplay.geometry]. A single instance, so that widgets rebuilding
  /// with it keep their subscription.
  late final Stream<DuoGeometry> geometry = Stream.multi((listener) {
    final last = _last;
    if (last != null) listener.add(last);
    final subscription = _changes.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
    // Also attaches the native observer when it is not yet.
    if (last == null) {
      unawaited(current().then<void>((_) {}, onError: listener.addError));
    }
  }, isBroadcast: true);

  /// See [DuoDisplay.current].
  Future<DuoGeometry?> current() async {
    _receive();
    final DuoGeometryMessage? message;
    try {
      message = await _hostApi.current();
    } on PlatformException catch (error) {
      if (error.code == _channelError) return null;
      rethrow;
    }
    return message == null ? null : _record(geometryFromMessage(message));
  }

  /// See [DuoDisplay.isSupported].
  Future<bool> isSupported() async {
    try {
      return await _hostApi.isSupported();
    } on PlatformException catch (error) {
      if (error.code == _channelError) return false;
      rethrow;
    }
  }

  @override
  void onGeometryChanged(DuoGeometryMessage geometry) {
    _record(geometryFromMessage(geometry));
  }

  DuoGeometry _record(DuoGeometry geometry) {
    if (geometry != _last) {
      _last = geometry;
      _changes.add(geometry);
    }
    return geometry;
  }

  void _receive() {
    if (_receiving) return;
    _receiving = true;
    DuoDisplayFlutterApi.setUp(this, binaryMessenger: _binaryMessenger);
  }
}
