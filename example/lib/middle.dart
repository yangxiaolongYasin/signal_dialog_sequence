// some_middleware.dart
import 'package:flutter/material.dart';
import 'package:signal_dialog_sequence/signal_dialog_sequence.dart';

class SomeMiddleware {
  static const String startupKey = 'home_startup';

  // 举例：当某个接口返回后，或者某个 Redux action 被捕获
  static Future<void> onSpecialEvent(BuildContext context) async {
    // ... 这里是你的中间件逻辑

    final needDialog = true; // 根据实际业务判断
    if (!needDialog) {
      DialogSequenceCenter.I.resolve(startupKey, 20, null);
      return;
    }

    DialogSequenceCenter.I.resolve(startupKey, 20, () {
      return showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('B 弹窗（来自中间件）'),
            content: const Text('这是由中间件插入的弹窗 (step 20)。'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭'))],
          );
        },
      );
    });
  }
}
