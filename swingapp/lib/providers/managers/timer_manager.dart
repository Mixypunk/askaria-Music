import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerManager {
  Timer? _sleepTimer;
  Timer? _periodicTimer;
  DateTime? _sleepAt;

  Duration? get remaining {
    if (_sleepAt == null) return null;
    final rem = _sleepAt!.difference(DateTime.now());
    return rem.isNegative ? null : rem;
  }
  
  bool get isActive => _sleepAt != null;

  void setTimer(int minutes, Future<void> Function() onTimerFinish, VoidCallback onUpdate) {
    cancel(onUpdate);
    if (minutes <= 0) return;
    
    _sleepAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await onTimerFinish();
      _sleepAt = null;
      onUpdate();
    });
    
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (t) {
      if (_sleepAt == null) { t.cancel(); _periodicTimer = null; return; }
      onUpdate();
    });
    onUpdate();
  }

  void cancel(VoidCallback onUpdate) {
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _sleepAt = null;
    onUpdate();
  }

  void dispose() {
    _sleepTimer?.cancel();
    _periodicTimer?.cancel();
  }
}
