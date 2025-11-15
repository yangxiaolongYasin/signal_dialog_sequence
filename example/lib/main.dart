import 'dart:math';

import 'package:example/middle.dart';
import 'package:flutter/material.dart';
import 'package:signal_dialog_sequence/signal_dialog_sequence.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _startupKey = 'home_startup';
  bool _firstEntered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_firstEntered) {
        _firstEntered = true;
        _startStartupFlow();
      }
    });
  }

  void _startStartupFlow() {
    DialogSequenceCenter.I.start(
      _startupKey,
      [10, 20, 30],
      onComplete: () {
        debugPrint('Home startup sequence completed');
      },
    );

    _loadA(); // step 10
    _loadB(); // step 20（假设这一步在中间件也有逻辑）
    _loadC(); // step 30
  }

  Future<void> _loadA() async {
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(400)));
    final needDialog = true;

    if (!mounted) return;

    if (needDialog) {
      DialogSequenceCenter.I.resolve(_startupKey, 10, () {
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              title: const Text('A 弹窗'),
              content: const Text('首页内部的第一个弹窗 (step 10)。'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭'))],
            );
          },
        );
      });
    } else {
      DialogSequenceCenter.I.resolve(_startupKey, 10, null);
    }
  }

  Future<void> _loadB() async {
    await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(300)));
    SomeMiddleware.onSpecialEvent(context);
  }

  Future<void> _loadC() async {
    await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(100)));
    final needDialog = true;

    if (!mounted) return;

    DialogSequenceCenter.I.resolve(_startupKey, 30, () {
      return showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('C 弹窗'),
            content: const Text('首页内部的第三个弹窗 (step 30)。'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭'))],
          );
        },
      );
    });
  }

  @override
  void dispose() {
    DialogSequenceCenter.I.cancel(_startupKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(onPressed: _startStartupFlow, child: const Text('重新触发首进序列（测试）')),
      ),
    );
  }
}
