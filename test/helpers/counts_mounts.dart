import 'package:flutter/widgets.dart';

/// A widget that reports each time it is mounted, to detect subtrees that
/// get torn down and rebuilt instead of updated.
class CountsMounts extends StatefulWidget {
  /// Creates the widget; [onMount] runs in every `initState`.
  const CountsMounts(this.onMount, {super.key});

  /// Called each time the widget is mounted.
  final VoidCallback onMount;

  @override
  State<CountsMounts> createState() => _CountsMountsState();
}

class _CountsMountsState extends State<CountsMounts> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
