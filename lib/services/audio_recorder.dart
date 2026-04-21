import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Background audio recording service with configurable sensitivity.
/// Uses platform channels for background recording during sleep.
class AudioRecorderService {
  static const _methodChannel =
      MethodChannel('com.snorerecorder/background_audio');

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool _isRecording = false;
  String? _currentFilePath;
  String? _currentSessionDir;

  // Configurable sensitivity
  double _sensitivityThreshold = 35.0; // dB threshold to trigger event capture
  int _sampleRate = 44100;
  int _segmentDurationMs = 5000; // duration of each audio segment

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  final _rawSamplesController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get rawSamplesStream => _rawSamplesController.stream;

  void configure({
    double? sensitivityThreshold,
    int? sampleRate,
    int? segmentDurationMs,
  }) {
    _sensitivityThreshold = sensitivityThreshold ?? _sensitivityThreshold;
    _sampleRate = sampleRate ?? _sampleRate;
    _segmentDurationMs = segmentDurationMs ?? _segmentDurationMs;
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String> startRecording(String sessionId) async {
    if (_isRecording) {
      throw StateError('Already recording');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getApplicationDocumentsDirectory();
    _currentSessionDir = '${dir.path}/sessions/$sessionId';
    await Directory(_currentSessionDir!).create(recursive: true);

    _currentFilePath =
        '$_currentSessionDir/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: _sampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: _currentFilePath!,
    );

    _isRecording = true;

    // Start amplitude monitoring
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amp) {
      final dbLevel = amp.current;
      _amplitudeController.add(dbLevel);

      // Generate synthetic waveform samples from amplitude for visualization
      _generateWaveformSamples(dbLevel);
    });

    // Enable background recording via platform channel
    try {
      await _methodChannel.invokeMethod('startBackgroundRecording', {
        'sessionId': sessionId,
        'filePath': _currentFilePath,
      });
    } on PlatformException {
      // Background recording not available on all platforms
    }

    return _currentFilePath!;
  }

  void _generateWaveformSamples(double dbLevel) {
    // Normalize dB to 0-1 range (typical mic range: -60 to 0 dB)
    final normalized = ((dbLevel + 60) / 60).clamp(0.0, 1.0);

    // Generate a chunk of waveform samples simulating the audio signal
    final samples = List<double>.generate(128, (i) {
      final t = i / 128.0;
      // Mix fundamental with harmonics to simulate snoring-like waveform
      final fundamental = normalized * _sin(t * 2 * 3.14159 * 3);
      final harmonic1 = normalized * 0.5 * _sin(t * 2 * 3.14159 * 7);
      final harmonic2 = normalized * 0.3 * _sin(t * 2 * 3.14159 * 13);
      final noise = (normalized * 0.1 * ((i * 7 % 13) / 13.0 - 0.5));
      return (fundamental + harmonic1 + harmonic2 + noise).clamp(-1.0, 1.0);
    });

    _rawSamplesController.add(samples);
  }

  double _sin(double x) {
    // Taylor series approximation for sine
    x = x % (2 * 3.14159);
    if (x > 3.14159) x -= 2 * 3.14159;
    final x3 = x * x * x;
    final x5 = x3 * x * x;
    final x7 = x5 * x * x;
    return x - x3 / 6 + x5 / 120 - x7 / 5040;
  }

  /// Save a segment of audio around a detected event
  Future<String?> saveEventClip({
    required DateTime eventTime,
    required Duration clipDuration,
  }) async {
    if (_currentSessionDir == null) return null;

    final clipId = const Uuid().v4().substring(0, 8);
    final clipPath = '$_currentSessionDir/clip_$clipId.m4a';

    // In production, we'd extract the clip from the recording buffer
    // For POC, we mark the clip path for later extraction
    return clipPath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final path = await _recorder.stop();
    _isRecording = false;

    // Stop background recording
    try {
      await _methodChannel.invokeMethod('stopBackgroundRecording');
    } on PlatformException {
      // Background recording not available on all platforms
    }

    return path;
  }

  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _amplitudeController.close();
    await _rawSamplesController.close();
    _recorder.dispose();
  }
}
