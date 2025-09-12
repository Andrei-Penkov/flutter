import 'package:flutter/material.dart';

import '../models/tip.dart';
import '../widgets/common_scaffold.dart';

class TipDetailScreen extends StatefulWidget {
  final String tipKey;
  final Tip tip;
  final ValueChanged<int> onStatusChanged;

  const TipDetailScreen({
    super.key,
    required this.tipKey,
    required this.tip,
    required this.onStatusChanged,
  });

  @override
  State<TipDetailScreen> createState() => _TipDetailScreenState();
}

class _TipDetailScreenState extends State<TipDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tip.status == 0) {
        widget.onStatusChanged(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> contentWidgets = [
      Text(widget.tip.tip, style: const TextStyle(fontSize: 16)),
    ];

    if (widget.tip.imagePath != null) {
      contentWidgets.add(const SizedBox(height: 16));
      contentWidgets.add(Image.asset(widget.tip.imagePath!));
    }

    return CommonScaffold(
      title: widget.tip.name,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
      ),
    );
  }
}
