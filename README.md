# signal_dialog_sequence

A small Flutter utility to control dialog display order using a fixed step sequence, even when async tasks complete out of order.

一个通过「步骤信号」来控制弹窗顺序的小工具。适用于首页首进、多接口并发请求、埋点中间件等场景，保证弹窗始终按照固定步骤顺序依次出现。

---

## 特性（Features）

- **固定顺序执行**  
  通过 `List<int> orderedSteps` 声明一个步骤序列（例如 `[10, 20, 30]`），  
  即使接口返回顺序是 20 → 10 → 30，**弹窗也会严格按 10 → 20 → 30 顺序显示**。

- **接口与 UI 解耦**  
  - 页面内部、ViewModel、Redux 中间件、Service 等任意地方，只要拿到 step id，就可以调用 [resolve](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3) 发出“步骤完成”的信号。  
  - 弹窗显示逻辑由序列统一调度，避免各层互相等待、嵌套回调。

- **可选弹窗**  
  - 某个步骤可以有弹窗：[resolve(step, callback)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3)  
  - 也可以没有弹窗：[resolve(step, null)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3)  
  所有步骤只要按顺序 [resolve](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3)，整体流程就会自动向前推进。

- **全局序列中心**  
  内置 [DialogSequenceCenter](cci:2://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:116:0-173:1)，通过字符串 key 管理多条序列（例如 `home_startup`、`mine_startup` 等），  
  支持：
  - **同 key 重复 start**：自动 cancel 旧序列，覆盖为新的。
  - **完成后自动回收**：序列完成时会自动从中心移除，避免内存泄漏。

- **取消与防御性设计**  
  - 支持随时 [cancel(key)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:69:2-74:3) 中断某条序列，后续步骤都不会再执行。  
  - 重复 [resolve](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3)、未知步骤、回调异常都会被安全忽略或记录日志，不会导致整个流程崩溃。

---

## 安装（Installing）

在你的 `pubspec.yaml` 中添加依赖（替换为你发布时的实际版本号）：

```yaml
dependencies:
  signal_dialog_sequence: ^0.0.1
```

然后执行：

```bash
flutter pub get
```

---

## 核心 API 概览

- **[DialogSequence](cci:2://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:12:0-113:1)**  
  一条「固定步骤顺序」的弹窗序列（通常由中心内部创建，你很少直接用它）。

- **[DialogSequenceCenter](cci:2://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:116:0-173:1)**  
  全局序列中心，通过字符串 key 管理多条序列。

常用方法：

- **[DialogSequenceCenter.I.start(key, orderedSteps, { onComplete })](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:123:2-150:3)**  
  启动一条新的序列。
- **[DialogSequenceCenter.I.resolve(key, step, DialogCallback? callback)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3)**  
  某一步完成：可以带弹窗回调，也可以为 `null` 表示无弹窗。
- **[DialogSequenceCenter.I.cancel(key)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:69:2-74:3)**  
  取消并移除一条序列。
- **[DialogSequenceCenter.I.hasSequence(key)](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:172:2-172:62)**  
  查询某个 key 的序列是否还存在。

---

## 基本用法示例（页面 + 接口）

假设首页有三个异步任务 A / B / C，对应步骤 10 / 20 / 30，  
你希望 **无论接口返回顺序如何，弹窗顺序始终是 A → B → C**。

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:signal_dialog_sequence/signal_dialog_sequence.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _startupKey = 'home_startup';
  final _random = Random();
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
    _loadB(); // step 20（也可以在中间件里触发）
    _loadC(); // step 30
  }

  Future<void> _loadA() async {
    await Future.delayed(
      Duration(milliseconds: 500 + _random.nextInt(400)),
    );
    if (!mounted) return;

    final needDialog = true;
    if (needDialog) {
      DialogSequenceCenter.I.resolve(
        _startupKey,
        10,
        () {
          return showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) {
              return AlertDialog(
                title: const Text('A 弹窗'),
                content: const Text('首页内部的第一个弹窗 (step 10)。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      DialogSequenceCenter.I.resolve(_startupKey, 10, null);
    }
  }

  Future<void> _loadB() async {
    await Future.delayed(
      Duration(milliseconds: 150 + _random.nextInt(300)),
    );
    if (!mounted) return;
    // 这里可以直接 resolve，也可以交给中间件，见下一节示例
  }

  Future<void> _loadC() async {
    await Future.delayed(
      Duration(milliseconds: 100 + _random.nextInt(100)),
    );
    if (!mounted) return;

    DialogSequenceCenter.I.resolve(
      _startupKey,
      30,
      () {
        return showDialog<void>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('C 弹窗'),
              content: const Text('首页内部的第三个弹窗 (step 30)。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
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
        child: ElevatedButton(
          onPressed: _startStartupFlow,
          child: const Text('重新触发首进序列（测试）'),
        ),
      ),
    );
  }
}
```

---

## 在中间件 / Service 中触发弹窗

你可以在任何拿得到 `BuildContext` 的地方（例如 Redux 中间件、某个服务）里使用同一个 key 来 [resolve](cci:1://file:///Users/yangxiaolong/flutter_work/test1/lib/dialog_sequence.dart:39:2-67:3) 某一步：

```dart
import 'package:flutter/material.dart';
import 'package:signal_dialog_sequence/signal_dialog_sequence.dart';

class SomeMiddleware {
  static const String startupKey = 'home_startup';

  static Future<void> onSpecialEvent(BuildContext context) async {
    final needDialog = true;
    if (!needDialog) {
      DialogSequenceCenter.I.resolve(startupKey, 20, null);
      return;
    }

    DialogSequenceCenter.I.resolve(
      startupKey,
      20,
      () {
        return showDialog<void>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('B 弹窗（来自中间件）'),
              content: const Text('这是由中间件插入的弹窗 (step 20)。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
```

---

## 取消序列

在页面销毁或业务不再需要序列时，可以调用：

```dart
DialogSequenceCenter.I.cancel('home_startup');
```

取消后：

- 当前已经在显示的弹窗不会被强制关闭（由用户自己关闭）。
- 后续步骤不会再弹窗，也不会触发 `onComplete`。

---

## 示例工程

本包自带一个 `example` 工程，演示了：

- 首页首进时触发多接口请求。
- 部分步骤在页面内部弹窗，部分步骤在“中间件”里弹窗。
- 多次触发同一个 key 的首进序列，用于开发期间反复调试。

你可以运行：

```bash
cd example
flutter run
```

来直接体验和验证这套弹窗顺序控制方案。