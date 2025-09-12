import 'package:flutter/material.dart';

class CommonScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onHome;

  const CommonScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Домой',
        onPressed: onHome ??
            () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            },
        child: const Icon(Icons.home),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: Image.asset('assets/images/tasks.png'),
                tooltip: 'К заданиям',
                onPressed: () {
                  Navigator.of(context).pushNamed('/tasks');
                }),
            const SizedBox(width: 48),
            IconButton(
                icon: Image.asset('assets/images/tips.png'),
                tooltip: 'К советам',
                onPressed: () {
                  Navigator.of(context).pushNamed('/tips');
                }),
          ],
        ),
      ),
    );
  }
}
