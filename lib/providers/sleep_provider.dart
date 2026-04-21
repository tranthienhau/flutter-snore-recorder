import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_event.dart';
import '../models/sleep_session.dart';
import '../services/audio_analyzer.dart';
import '../services/audio_recorder.dart';
import '../services/sleep_detector.dart';

// --- Service Providers ---

final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

final audioAnalyzerProvider = Provider<AudioAnalyzer>((ref) {
  return AudioAnalyzer();
});

final sleepDetectorProvider = Provider<SleepDetector>((ref) {
  final detector = SleepDetector();
  ref.onDispose(() => detector.dispose());
  return detector;
});

// --- State Providers ---

final isRecordingProvider = StateProvider<bool>((ref) => false);
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Live amplitude stream for waveform visualization
final amplitudeStreamProvider = StreamProvider<double>((ref) {
  final recorder = ref.watch(audioRecorderProvider);
  return recorder.amplitudeStream;
});

/// Live waveform samples for real-time visualization
final waveformSamplesProvider = StreamProvider<List<double>>((ref) {
  final recorder = ref.watch(audioRecorderProvider);
  return recorder.rawSamplesStream;
});

/// Sleep state changes
final sleepStateProvider = StreamProvider<SleepState>((ref) {
  final detector = ref.watch(sleepDetectorProvider);
  return detector.sleepStateStream;
});

/// Current recording events collected in real-time
final currentEventsProvider =
    StateNotifierProvider<CurrentEventsNotifier, List<AudioEvent>>((ref) {
  return CurrentEventsNotifier();
});

class CurrentEventsNotifier extends StateNotifier<List<AudioEvent>> {
  CurrentEventsNotifier() : super([]);

  void addEvent(AudioEvent event) {
    state = [...state, event];
  }

  void clear() {
    state = [];
  }
}

/// All stored sleep sessions
final sleepSessionsProvider =
    StateNotifierProvider<SleepSessionsNotifier, List<SleepSession>>((ref) {
  return SleepSessionsNotifier();
});

class SleepSessionsNotifier extends StateNotifier<List<SleepSession>> {
  SleepSessionsNotifier() : super([]) {
    _loadSessions();
  }

  void _loadSessions() {
    final box = Hive.box('sleep_sessions');
    final sessions = <SleepSession>[];
    for (final key in box.keys) {
      try {
        final json = jsonDecode(box.get(key) as String);
        sessions.add(SleepSession.fromJson(json));
      } catch (_) {}
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    state = sessions;
  }

  Future<void> saveSession(SleepSession session) async {
    final box = Hive.box('sleep_sessions');
    await box.put(session.id, jsonEncode(session.toJson()));
    _loadSessions();
  }

  Future<void> deleteSession(String id) async {
    final box = Hive.box('sleep_sessions');
    await box.delete(id);
    _loadSessions();
  }

  SleepSession? getSession(String id) {
    try {
      return state.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

// --- Recording Controller ---

final recordingControllerProvider =
    Provider<RecordingController>((ref) => RecordingController(ref));

class RecordingController {
  final Ref _ref;
  Timer? _analysisTimer;
  final List<double> _recentAmplitudes = [];

  RecordingController(this._ref);

  Future<void> startRecording() async {
    final recorder = _ref.read(audioRecorderProvider);
    final detector = _ref.read(sleepDetectorProvider);
    final sessionId = const Uuid().v4();

    _ref.read(currentSessionIdProvider.notifier).state = sessionId;
    _ref.read(currentEventsProvider.notifier).clear();

    await recorder.startRecording(sessionId);
    detector.startMonitoring();
    _ref.read(isRecordingProvider.notifier).state = true;

    // Start periodic audio analysis
    _analysisTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _analyzeCurrentAudio(),
    );

    // Listen to amplitude for sleep detection
    recorder.amplitudeStream.listen((db) {
      detector.addAudioSample(db);
      _recentAmplitudes.add(db);
      if (_recentAmplitudes.length > 200) {
        _recentAmplitudes.removeAt(0);
      }
    });
  }

  void _analyzeCurrentAudio() {
    final analyzer = _ref.read(audioAnalyzerProvider);
    final recorder = _ref.read(audioRecorderProvider);

    // Analyze recent samples via waveform stream
    recorder.rawSamplesStream.first.then((samples) {
      if (samples.isEmpty) return;

      final result = analyzer.analyzeChunk(samples);

      if (result.type != AudioEventType.silence) {
        final event = AudioEvent(
          timestamp: DateTime.now(),
          duration: const Duration(seconds: 5),
          type: result.type,
          decibelLevel: result.decibelLevel,
          confidence: result.confidence,
          dominantFrequency: result.dominantFrequency,
        );
        _ref.read(currentEventsProvider.notifier).addEvent(event);
      }
    }).catchError((_) {});
  }

  Future<SleepSession> stopRecording() async {
    final recorder = _ref.read(audioRecorderProvider);
    final detector = _ref.read(sleepDetectorProvider);
    final analyzer = _ref.read(audioAnalyzerProvider);
    final sessionId = _ref.read(currentSessionIdProvider)!;
    final events = _ref.read(currentEventsProvider);

    _analysisTimer?.cancel();
    _analysisTimer = null;

    final filePath = await recorder.stopRecording();
    detector.stopMonitoring();
    _ref.read(isRecordingProvider.notifier).state = false;

    final sleepMetrics = detector.getSleepMetrics();
    final startTime = events.isNotEmpty
        ? events.first.timestamp
        : DateTime.now().subtract(const Duration(hours: 1));
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    final snoreScore = analyzer.calculateSnoreScore(
      events: events,
      totalDuration: duration,
    );

    final snoreEvents =
        events.where((e) => e.type == AudioEventType.snoring).toList();
    final avgDb = events.isNotEmpty
        ? events.fold(0.0, (sum, e) => sum + e.decibelLevel) / events.length
        : 0.0;
    final maxDb = events.isNotEmpty
        ? events.map((e) => e.decibelLevel).reduce((a, b) => a > b ? a : b)
        : 0.0;

    final totalSnoreDuration = snoreEvents.fold<Duration>(
      Duration.zero,
      (sum, e) => sum + e.duration,
    );

    final quality = snoreScore <= 20
        ? SleepQuality.excellent
        : snoreScore <= 40
            ? SleepQuality.good
            : snoreScore <= 65
                ? SleepQuality.fair
                : SleepQuality.poor;

    final session = SleepSession(
      id: sessionId,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      events: events,
      snoreScore: snoreScore,
      averageDecibel: avgDb,
      maxDecibel: maxDb,
      totalSnoreEvents: snoreEvents.length,
      totalSnoreDuration: totalSnoreDuration,
      audioSegmentPaths: filePath != null ? [filePath] : [],
      quality: quality,
    );

    await _ref.read(sleepSessionsProvider.notifier).saveSession(session);
    _ref.read(currentSessionIdProvider.notifier).state = null;
    _recentAmplitudes.clear();

    return session;
  }
}

// --- Insight Providers ---

/// Remedies tracking store
final remediesProvider =
    StateNotifierProvider<RemediesNotifier, Map<String, List<RemedyEntry>>>(
        (ref) {
  return RemediesNotifier();
});

class RemedyEntry {
  final String sessionId;
  final String remedy;
  final bool used;
  final DateTime date;

  RemedyEntry({
    required this.sessionId,
    required this.remedy,
    required this.used,
    required this.date,
  });
}

class RemediesNotifier
    extends StateNotifier<Map<String, List<RemedyEntry>>> {
  RemediesNotifier() : super({}) {
    _loadRemedies();
  }

  void _loadRemedies() {
    final box = Hive.box('remedies');
    // Load stored remedies
    final data = <String, List<RemedyEntry>>{};
    for (final key in box.keys) {
      try {
        final entries = (jsonDecode(box.get(key)) as List)
            .map((e) => RemedyEntry(
                  sessionId: e['sessionId'],
                  remedy: e['remedy'],
                  used: e['used'],
                  date: DateTime.parse(e['date']),
                ))
            .toList();
        data[key as String] = entries;
      } catch (_) {}
    }
    state = data;
  }

  void addRemedy(String sessionId, String remedy, bool used) {
    final entry = RemedyEntry(
      sessionId: sessionId,
      remedy: remedy,
      used: used,
      date: DateTime.now(),
    );
    final current = state[remedy] ?? [];
    state = {...state, remedy: [...current, entry]};

    // Persist
    final box = Hive.box('remedies');
    box.put(
      remedy,
      jsonEncode(state[remedy]!
          .map((e) => {
                'sessionId': e.sessionId,
                'remedy': e.remedy,
                'used': e.used,
                'date': e.date.toIso8601String(),
              })
          .toList()),
    );
  }
}
