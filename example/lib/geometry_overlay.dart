import 'dart:ui' show DisplayFeature;

import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';

/// Draws the current [DuoGeometry] over the app: the hinge band, camera
/// cutouts and status columns, plus a card with every value.
class GeometryOverlay extends StatefulWidget {
  const GeometryOverlay({super.key});

  @override
  State<GeometryOverlay> createState() => _GeometryOverlayState();
}

class _GeometryOverlayState extends State<GeometryOverlay> {
  late final Future<bool> _supported = DuoDisplay.isSupported;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: StreamBuilder<DuoGeometry>(
        stream: DuoDisplay.geometry,
        builder: (context, snapshot) {
          final geometry = snapshot.data;
          return Stack(
            children: [
              if (geometry != null)
                Positioned.fill(
                  child: CustomPaint(painter: _RegionsPainter(geometry)),
                ),
              Align(
                alignment: Alignment.bottomLeft,
                child: SafeArea(
                  child: FutureBuilder<bool>(
                    future: _supported,
                    builder: (context, supported) => _GeometryCard(
                      geometry: geometry,
                      supported: supported.data,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GeometryCard extends StatelessWidget {
  const _GeometryCard({required this.geometry, required this.supported});

  final DuoGeometry? geometry;
  final bool? supported;

  @override
  Widget build(BuildContext context) {
    final geometry = this.geometry;
    final lines = <String>[
      'supported: ${supported ?? '…'}',
      if (geometry == null)
        'geometry: none yet'
      else ...[
        'posture: ${geometry.posture.name}',
        'screen: ${geometry.screen.name}',
        'hingeAngle: ${geometry.hingeAngle?.toStringAsFixed(1) ?? '–'}°',
        'hinge: ${_rect(geometry.hinge)}',
        'cutouts: ${geometry.cutouts.map(_rect).join(', ')}',
        'statusColumns: ${geometry.statusColumns.map(_rect).join(', ')}',
        'verticalBars: ${geometry.verticalBars}',
        'isSplitView: ${geometry.isSplitView}',
      ],
      'MediaQuery: ${_size(MediaQuery.sizeOf(context))}',
      'displayFeatures: ${_features(MediaQuery.displayFeaturesOf(context))}',
    ];
    return Card(
      margin: const EdgeInsets.all(12),
      color: Colors.black.withValues(alpha: 0.75),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          lines.join('\n'),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Menlo',
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  static String _rect(Rect? rect) => rect == null
      ? '–'
      : '${_number(rect.width)}×${_number(rect.height)}'
            '@${_number(rect.left)},${_number(rect.top)}';

  static String _features(List<DisplayFeature> features) => features.isEmpty
      ? 'none'
      : features
            .map((feature) => '${feature.type.name}(${feature.state.name})')
            .join(', ');

  static String _size(Size size) =>
      '${_number(size.width)}×${_number(size.height)}';

  static String _number(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}

class _RegionsPainter extends CustomPainter {
  _RegionsPainter(this.geometry);

  final DuoGeometry geometry;

  static final _hingePaint = Paint()
    ..color = Colors.amber.withValues(alpha: 0.45);
  static final _cutoutPaint = Paint()
    ..color = Colors.red.withValues(alpha: 0.6);
  static final _statusPaint = Paint()
    ..color = Colors.lightBlue.withValues(alpha: 0.45);

  @override
  void paint(Canvas canvas, Size size) {
    final hinge = geometry.hinge;
    if (hinge != null) canvas.drawRect(hinge, _hingePaint);
    for (final column in geometry.statusColumns) {
      canvas.drawRect(column, _statusPaint);
    }
    for (final cutout in geometry.cutouts) {
      canvas.drawRect(cutout, _cutoutPaint);
    }
  }

  @override
  bool shouldRepaint(_RegionsPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}
