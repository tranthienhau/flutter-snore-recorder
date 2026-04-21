import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects sleep onset and wakeup from audio patterns and accelerometer data.
class SleepDetector {
  static const int _windowSizeMinutes = 5;
  static const double _movementThreshold = 0.3;
  static const double _sleepOnsetDbThreshold = -40.0;
  static const int _quietMinutesForSleep = 10;

  final List<_MovementSample> _movementHistory = [];
  final List<_AudioSample> _audioHistory = [];

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  double _lastAccelMagnitude = 0;
  DateTime? _sleepOnsetTime;
  DateTime? _wakeupTime;
  bool _isSleeping = false;

  final _sleepStateController = StreamController<SleepState>.broadcast();
  Stream<SleepState> get sleepStateStream => _sleepStateController.stream;

  bool get isSleeping => _isSleeping;
  DateTime? get sleepOnsetTime => _sleepOnsetTime;
  DateTime? get wakeupTime => _wakeupTime;

  void startMonitoring() {
    _accelerometerSub = accelerometerEventStream().listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final delta = (magnitude - _lastAccelMagnitude).abs();
      _lastAccelMagnitude = magnitude;

      _movementHistory.add(_MovementSample(
        timestamp: DateTime.now(),
        magnitude: delta,
      ));

      // Keep only last 30 minutes of movement data
      _pruneHistory();
      _evaluateSleepState();
    });
  }

  /// Feed audio amplitude data for sleep detection
  void addAudioSample(double decibelLevel) {
    _audioHistory.add(_AudioSample(
      timestamp: DateTime.now(),
      decibelLevel: decibelLevel,
    ));
    _pruneHistory();
    _evaluateSleepState();
  }

  void _pruneHistory() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    _movementHistory.removeWhere((s) => s.timestamp.isBefore(cutoff));
    _audioHistory.removeWhere((s) => s.timestamp.isBefore(cutoff));
  }

  void _evaluateSleepState() {
    final now = DateTime.now();
    final windowStart =
        now.subtract(Duration(minutes: _quietMinutesForSleep));

    // Check movement in the analysis window
    final recentMovements = _movementHistory
        .where((s) => s.timestamp.isAfter(windowStart))
        .toList();

    final recentAudio = _audioHistory
        .where((s) => s.timestamp.isAfter(windowStart))
        .toList();

    if (recentMovements.isEmpty && recentAudio.isEmpty) return;

    // Calculate average movement intensity
    final avgMovement = recentMovements.isEmpty
        ? 0.0
        : recentMovements.fold(0.0, (sum, s) => sum + s.magnitude) /
            recentMovements.length;

    // Calculate average audio level
    final avgAudio = recentAudio.isEmpty
        ? -60.0
        : recentAudio.fold(0.0, (sum, s) => sum + s.decibelLevel) /
            recentAudio.length;

    final wasAsleep = _isSleeping;

    // Sleep onset: low movement + quiet audio for sustained period
    if (!_isSleeping &&
        avgMovement < _movementThreshold &&
        avgAudio < _sleepOnsetDbThreshold &&
        recentMovements.length > 20) {
      _isSleeping = true;
      _sleepOnsetTime = windowStart;
      _sleepStateController.add(SleepState(
        state: SleepPhase.asleep,
        timestamp: _sleepOnsetTime!,
        confidence: _calculateConfidence(avgMovement, avgAudio),
      ));
    }

    // Wakeup detection: significant movement spike or sustained loud audio
    if (_isSleeping && (avgMovement > _movementThreshold * 3 ||
        avgAudio > -20.0)) {
      // Check if it's a brief disturbance or actual wakeup
      final recentHighMovement = recentMovements
          .where((s) =>
              s.magnitude > _movementThreshold * 2 &&
              s.timestamp.isAfter(
                  now.subtract(const Duration(minutes: 2))))
          .length;

      if (recentHighMovement > 10) {
        _isSleeping = false;
        _wakeupTime = now;
        _sleepStateController.add(SleepState(
          state: SleepPhase.awake,
          timestamp: now,
          confidence: _calculateConfidence(avgMovement, avgAudio),
        ));
      }
    }

    // Light sleep detection: some movement, moderate audio
    if (_isSleeping && wasAsleep) {
      if (avgMovement > _movementThreshold * 0.5 &&
          avgMovement < _movementThreshold * 2) {
        _sleepStateController.add(SleepState(
          state: SleepPhase.lightSleep,
          timestamp: now,
          confidence: 0.6,
        ));
      }
    }
  }

  double _calculateConfidence(double avgMovement, double avgAudio) {
    // Higher confidence when movement is very low and audio is very quiet
    final movementConf = (1.0 - avgMovement / (_movementThreshold * 2))
        .clamp(0.0, 1.0);
    final audioConf = ((_sleepOnsetDbThreshold - avgAudio) / 20.0)
        .clamp(0.0, 1.0);
    return (movementConf * 0.6 + audioConf * 0.4).clamp(0.0, 1.0);
  }

  /// Get sleep metrics for the current session
  SleepMetrics getSleepMetrics() {
    if (_sleepOnsetTime == null) {
      return SleepMetrics(
        sleepLatencyMinutes: 0,
        estimatedSleepDuration: Duration.zero,
        movementCount: 0,
        restlessnessScore: 0.0,
      );
    }

    final endTime = _wakeupTime ?? DateTime.now();
    final sleepDuration = endTime.difference(_sleepOnsetTime!);

    // Count significant movement events during sleep
    final sleepMovements = _movementHistory
        .where((s) =>
            s.timestamp.isAfter(_sleepOnsetTime!) &&
            s.timestamp.isBefore(endTime) &&
            s.magnitude > _movementThreshold)
        .length;

    final restlessness = sleepDuration.inMinutes > 0
        ? sleepMovements / sleepDuration.inMinutes * 10
        : 0.0;

    return SleepMetrics(
      sleepLatencyMinutes: _sleepOnsetTime!
          .difference(_movementHistory.first.timestamp)
          .inMinutes,
      estimatedSleepDuration: sleepDuration,
      movementCount: sleepMovements,
      restlessnessScore: restlessness.clamp(0.0, 10.0),
    );
  }

  void stopMonitoring() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
  }

  void dispose() {
    stopMonitoring();
    _sleepStateController.close();
  }
}

class _MovementSample {
  final DateTime timestamp;
  final double magnitude;

  _MovementSample({required this.timestamp, required this.magnitude});
}

class _AudioSample {
  final DateTime timestamp;
  final double decibelLevel;

  _AudioSample({required this.timestamp, required this.decibelLevel});
}

enum SleepPhase { awake, falling, lightSleep, deepSleep, asleep }

class SleepState {
  final SleepPhase state;
  final DateTime timestamp;
  final double confidence;

  SleepState({
    required this.state,
    required this.timestamp,
    required this.confidence,
  });
}

class SleepMetrics {
  final int sleepLatencyMinutes;
  final Duration estimatedSleepDuration;
  final int movementCount;
  final double restlessnessScore;

  SleepMetrics({
    required this.sleepLatencyMinutes,
    required this.estimatedSleepDuration,
    required this.movementCount,
    required this.restlessnessScore,
  });
}
