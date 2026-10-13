import 'package:duo_display/duo_display.dart';
import 'package:duo_display_example/geometry_overlay.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'duo_display',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      // Above the navigator, so the overlay stays visible on every page.
      builder: (context, child) => Stack(
        children: [
          ?child,
          const GeometryOverlay(),
        ],
      ),
      home: const ItemListPage(),
    );
  }
}

class ItemListPage extends StatelessWidget {
  const ItemListPage({super.key});

  static const itemCount = 40;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) => ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text('Item ${index + 1}'),
          subtitle: const Text('Tap to open'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ItemDetailPage(index: index),
            ),
          ),
        ),
      ),
    );
  }
}

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Item ${index + 1}')),
      body: Center(
        child: StreamBuilder<DuoGeometry>(
          stream: DuoDisplay.geometry,
          builder: (context, snapshot) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Item ${index + 1}', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Posture: ${snapshot.data?.posture.name ?? 'unknown'}',
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
