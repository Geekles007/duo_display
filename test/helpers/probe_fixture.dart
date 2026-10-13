import 'dart:convert';
import 'dart:io';

import 'package:duo_display/src/messages.g.dart';

/// Loads a DuoProbe capture from `test/fixtures` and converts it into the
/// message the native observer sends for the same geometry.
DuoGeometryMessage probeFixture(String name) {
  final file = File('test/fixtures/$name.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hinge = json['hinge'] as Map<String, dynamic>?;
  return DuoGeometryMessage(
    viewSize: _size(json['viewBounds']),
    windowSize: _size(json['window']),
    screenSize: _size(json['sceneScreenBounds']),
    hingeStatus: hinge == null
        ? null
        : HingeStatusMessage.values.byName(hinge['status'] as String),
    hingeAngle: (hinge?['angleRad'] as num?)?.toDouble(),
    verticalBarEdge: VerticalBarEdgeMessage.values.byName(
      json['verticalBarEdge'] as String,
    ),
    regions: [
      for (final region in json['regions'] as List<dynamic>)
        _region(region as Map<String, dynamic>),
    ],
  );
}

RegionMessage _region(Map<String, dynamic> json) => RegionMessage(
  kind: RegionKindMessage.values.byName(json['kind'] as String),
  active: json['active'] as bool,
  frame: _rect(json['frame']),
);

SizeMessage _size(Object? json) {
  final map = json! as Map<String, dynamic>;
  return SizeMessage(
    width: (map['w'] as num).toDouble(),
    height: (map['h'] as num).toDouble(),
  );
}

RectMessage _rect(Object? json) {
  final map = json! as Map<String, dynamic>;
  return RectMessage(
    x: (map['x'] as num).toDouble(),
    y: (map['y'] as num).toDouble(),
    width: (map['w'] as num).toDouble(),
    height: (map['h'] as num).toDouble(),
  );
}
