import 'package:duo_display/duo_display.dart';
import 'package:duo_display_example/geometry_overlay.dart';
import 'package:flutter/material.dart';

// DuoDisplayFeatures reports the fold in MediaQuery.displayFeatures in Book
// posture, so the dialogs and bottom sheets below avoid it without any
// iPhone Duo code. Flat, they can span the whole screen.
void main() => runApp(const DuoDisplayFeatures(child: ExampleApp()));

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

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});

  static const itemCount = 40;

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  int _selected = 0;
  bool _splitWhenFlat = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          const Text('Split when flat'),
          Switch(
            value: _splitWhenFlat,
            onChanged: (value) => setState(() => _splitWhenFlat = value),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExampleDialog(context),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Dialog'),
      ),
      // Two panes around the hinge in Book (and when flat, with the switch
      // on): the list on one side, the selected item on the other.
      body: DuoLayoutBuilder(
        splitWhenFlat: _splitWhenFlat,
        builder: (context, layout) => layout.place(
          first: ListView.builder(
            itemCount: ItemListPage.itemCount,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text('Item ${index + 1}'),
              subtitle: Text(layout.isSplit ? 'Tap to show' : 'Tap to open'),
              selected: layout.isSplit && index == _selected,
              onTap: () => layout.isSplit
                  ? setState(() => _selected = index)
                  : Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ItemDetailPage(index: index),
                      ),
                    ),
            ),
          ),
          second: ItemDetailView(index: _selected),
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
    return Scaffold(
      appBar: AppBar(title: Text('Item ${index + 1}')),
      body: ItemDetailView(index: index),
    );
  }
}

class ItemDetailView extends StatelessWidget {
  const ItemDetailView({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => showExampleDialog(context),
              child: const Text('Show dialog'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('Bottom sheet')),
                ),
              ),
              child: const Text('Show bottom sheet'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showExampleDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Dialog'),
    content: const Text(
      'In Book posture, this opens on one side of the fold. Flat, it can '
      'span the whole screen.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
