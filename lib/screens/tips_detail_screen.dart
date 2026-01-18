import 'package:flutter/material.dart';
import '../models/tip.dart';
import '../widgets/common_scaffold.dart';

typedef TipStatusCallback = void Function(String tipKey, int status);

class TipDetailScreen extends StatefulWidget {
  final String tipKey;
  final Tip tip;
  final TipStatusCallback onStatusChanged;

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
        widget.onStatusChanged(widget.tipKey, 1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStatusChanged(widget.tipKey, 1);
    });
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    List<Widget> contentWidgets = [
      Text(widget.tip.tip, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      // Text('Key: "${widget.tipKey}"', style: TextStyle(fontSize: 12, color: Colors.grey)),
    ];

    if (widget.tip.imagePath != null && widget.tip.imagePath!.isNotEmpty) {
      contentWidgets.addAll([
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(widget.tip.imagePath!, height: 200, fit: BoxFit.cover),
        ),
      ]);
    }

    return CommonScaffold(
      title: widget.tip.name,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentWidgets,
          ),
        ),
      ),
    );
  }
}
