import 'package:flutter/material.dart';

void main() {
  runApp(const StackCardApp());
}

class StackCardApp extends StatelessWidget {
  const StackCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StackCard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BootstrapPage(),
    );
  }
}

// Счётчик проверяет запуск и обновление UI; продуктовые экраны появятся в Phase 1.
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() => _counter++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('StackCard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Нажатий на кнопку:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Увеличить счётчик',
        child: const Icon(Icons.add),
      ),
    );
  }
}
