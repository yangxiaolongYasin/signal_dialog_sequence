import 'dart:async';

import 'package:flutter/foundation.dart';

typedef DialogCallback = FutureOr<void> Function();

class _StepState {
  bool resolved = false;
  DialogCallback? callback;
}

/// 一条「固定步骤顺序」的弹窗序列
class DialogSequence {
  DialogSequence(List<int> orderedSteps, {this.onComplete}) : _orderedSteps = List<int>.from(orderedSteps) {
    assert(_orderedSteps.isNotEmpty, 'orderedSteps cannot be empty');
    for (final step in _orderedSteps) {
      // 防止重复 step（开发期尽早暴露配置错误）
      assert(!_steps.containsKey(step), 'DialogSequence: orderedSteps has duplicated step: $step');
      _steps[step] = _StepState();
    }
  }

  final List<int> _orderedSteps;
  final Map<int, _StepState> _steps = <int, _StepState>{};

  int _currentIndex = 0;
  bool _isRunning = false;
  bool _isCompleted = false;

  final VoidCallback? onComplete;

  bool get isCompleted => _isCompleted;

  /// 某一步的接口完成后调用：
  /// - 有弹窗：resolve(step, callback)
  /// - 不弹窗：resolve(step, null)
  void resolve(int step, DialogCallback? callback) {
    if (_isCompleted) return;

    final state = _steps[step];
    if (state == null) {
      if (kDebugMode) {
        debugPrint('DialogSequence.resolve: unknown step $step, ignore.');
      }
      return;
    }

    if (state.resolved) {
      if (kDebugMode) {
        debugPrint('DialogSequence.resolve: step $step already resolved, ignore.');
      }
      return;
    }

    state.resolved = true;
    state.callback = callback;
    _tryRun();
  }

  /// 取消整条序列：后续步骤都不会再执行
  void cancel() {
    if (_isCompleted) return;
    _isCompleted = true;
    _steps.clear();
  }

  Future<void> _tryRun() async {
    if (_isRunning || _isCompleted) return;
    _isRunning = true;

    try {
      while (!_isCompleted && _currentIndex < _orderedSteps.length) {
        final stepKey = _orderedSteps[_currentIndex];
        final state = _steps[stepKey];

        // 这一步对应的接口还没返回，不能继续往前
        if (state == null || !state.resolved) break;

        final DialogCallback? callback = state.callback;
        _currentIndex++;

        if (callback != null) {
          try {
            await callback(); // 这里一般是 await showDialog(...)
          } catch (e, s) {
            if (kDebugMode) {
              debugPrint('DialogSequence: error in step $stepKey: $e\n$s');
            }
            // 吞掉异常，继续后面步骤
          }
        }
      }

      if (_currentIndex >= _orderedSteps.length && !_isCompleted) {
        _isCompleted = true;
        onComplete?.call();
      }
    } finally {
      _isRunning = false;
    }
  }
}

/// 全局序列中心：用字符串 key 管理多条 DialogSequence
class DialogSequenceCenter {
  DialogSequenceCenter._();

  static final DialogSequenceCenter I = DialogSequenceCenter._();

  final Map<String, DialogSequence> _sequences = <String, DialogSequence>{};

  /// 启动一条新的序列：
  /// - key 用来标识这条流（比如 'home_startup'）
  /// - 如果同一个 key 已经有旧序列，会先 cancel 再覆盖
  DialogSequence start(String key, List<int> orderedSteps, {VoidCallback? onComplete}) {
    // 先取消旧的
    final old = _sequences.remove(key);
    old?.cancel();
    // 先声明，再在下一行赋值，闭包可以安全捕获 seq
    late final DialogSequence seq;
    seq = DialogSequence(
      orderedSteps,
      onComplete: () {
        // 只在 map 里当前还是这条 seq 时才移除，避免误删新序列
        if (_sequences[key] == seq) {
          // 完成后自动从中心移除，避免内存泄漏
          _sequences.remove(key);
        }
        onComplete?.call();
      },
    );

    _sequences[key] = seq;
    return seq;
  }

  /// 某个 key 对应的序列的某一步完成
  void resolve(String key, int step, DialogCallback? callback) {
    final seq = _sequences[key];
    if (seq == null) {
      if (kDebugMode) {
        debugPrint('DialogSequenceCenter.resolve: sequence "$key" not found, ignore.');
      }
      return;
    }
    seq.resolve(step, callback);
  }

  /// 取消并移除一条序列
  void cancel(String key) {
    final seq = _sequences.remove(key);
    seq?.cancel();
  }

  bool hasSequence(String key) => _sequences.containsKey(key);
}
