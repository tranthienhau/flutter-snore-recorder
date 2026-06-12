import 'dart:math';
import 'dart:typed_data';
import 'package:fft/fft.dart';

import '../models/audio_event.dart';

/// FFT-based audio analysis service for snore detection.
///
/// Detects snoring patterns in the frequency range 30-500Hz,
/// classifies audio segments (snore, talk, cough, ambient),
/// calculates snore score (0-100), and measures decibel levels.
class AudioAnalyzer {
  static const int _fftSize = 2048;
  static const double _sampleRate = 44100.0;
  static const double _snoreMinFreq = 30.0;
  static const double _snoreMaxFreq = 500.0;
  static const double _speechMinFreq = 300.0;
  static const double _speechMaxFreq = 3400.0;
  static const double _coughMinFreq = 200.0;
  static const double _coughMaxFreq = 2000.0;

  // Thresholds for classification
  static const double _silenceThresholdDb = -50.0;
  static const double _snoreEnergyRatio = 0.35;
  static const double _speechEnergyRatio = 0.30;
  static const double _coughEnergyRatio = 0.25;
  static const double _coughDurationMaxMs = 500.0;

  final _window = _hannWindow(_fftSize);

  /// Analyze a chunk of raw audio samples and classify the audio event.
  AudioClassification analyzeChunk(List<double> samples) {
    if (samples.length < _fftSize) {
      return AudioClassification(
        type: AudioEventType.silence,
        confidence: 1.0,
        decibelLevel: -60.0,
        dominantFrequency: 0.0,
        frequencySpectrum: [],
      );
    }

    // Apply Hann window to reduce spectral leakage
    final windowed = List<double>.generate(
      _fftSize,
      (i) => samples[i] * _window[i],
    );

    // Perform FFT
    final fftResult = FFT.Transform(windowed);

    // Compute magnitude spectrum (first half, due to symmetry)
    final halfSize = _fftSize ~/ 2;
    final magnitudes = List<double>.generate(halfSize, (i) {
      final real = fftResult[i].real;
      final imag = fftResult[i].imaginary;
      return sqrt(real * real + imag * imag);
    });

    // Calculate frequency resolution
    final freqResolution = _sampleRate / _fftSize;

    // Compute energy in specific frequency bands
    final snoreEnergy = _bandEnergy(magnitudes, freqResolution,
        _snoreMinFreq, _snoreMaxFreq);
    final speechEnergy = _bandEnergy(magnitudes, freqResolution,
        _speechMinFreq, _speechMaxFreq);
    final coughEnergy = _bandEnergy(magnitudes, freqResolution,
        _coughMinFreq, _coughMaxFreq);
    final totalEnergy = magnitudes.fold(0.0, (sum, m) => sum + m * m);

    // Calculate RMS and decibel level
    final rms = sqrt(samples.fold(0.0, (sum, s) => sum + s * s) /
        samples.length);
    final decibelLevel = rms > 0 ? 20 * log(rms) / ln10 : -60.0;

    // Find dominant frequency
    int peakIndex = 0;
    double peakMag = 0;
    for (int i = 1; i < halfSize; i++) {
      if (magnitudes[i] > peakMag) {
        peakMag = magnitudes[i];
        peakIndex = i;
      }
    }
    final dominantFrequency = peakIndex * freqResolution;

    // Classify audio event
    final classification = _classify(
      snoreEnergy: snoreEnergy,
      speechEnergy: speechEnergy,
      coughEnergy: coughEnergy,
      totalEnergy: totalEnergy,
      decibelLevel: decibelLevel,
      dominantFrequency: dominantFrequency,
    );

    return AudioClassification(
      type: classification.type,
      confidence: classification.confidence,
      decibelLevel: decibelLevel,
      dominantFrequency: dominantFrequency,
      frequencySpectrum: magnitudes,
    );
  }

  /// Compute energy in a specific frequency band
  double _bandEnergy(
    List<double> magnitudes,
    double freqResolution,
    double minFreq,
    double maxFreq,
  ) {
    final minBin = (minFreq / freqResolution).floor();
    final maxBin = (maxFreq / freqResolution).ceil().clamp(0, magnitudes.length - 1);

    double energy = 0;
    for (int i = minBin; i <= maxBin; i++) {
      energy += magnitudes[i] * magnitudes[i];
    }
    return energy;
  }

  /// Classify audio based on frequency band energy distribution
  ({AudioEventType type, double confidence}) _classify({
    required double snoreEnergy,
    required double speechEnergy,
    required double coughEnergy,
    required double totalEnergy,
    required double decibelLevel,
    required double dominantFrequency,
  }) {
    // Silence detection
    if (decibelLevel < _silenceThresholdDb || totalEnergy < 1e-6) {
      return (type: AudioEventType.silence, confidence: 0.95);
    }

    final snoreRatio = totalEnergy > 0 ? snoreEnergy / totalEnergy : 0.0;
    final speechRatio = totalEnergy > 0 ? speechEnergy / totalEnergy : 0.0;

    // Snoring: dominant energy in 30-500Hz band, rhythmic pattern
    if (snoreRatio > _snoreEnergyRatio &&
        dominantFrequency >= _snoreMinFreq &&
        dominantFrequency <= _snoreMaxFreq) {
      final confidence = (snoreRatio * 1.5).clamp(0.0, 1.0);
      return (type: AudioEventType.snoring, confidence: confidence);
    }

    // Speech: dominant energy in 300-3400Hz band
    if (speechRatio > _speechEnergyRatio &&
        dominantFrequency >= _speechMinFreq &&
        dominantFrequency <= _speechMaxFreq) {
      final confidence = (speechRatio * 1.2).clamp(0.0, 1.0);
      return (type: AudioEventType.talking, confidence: confidence);
    }

    // Coughing: broadband burst in 200-2000Hz range (short duration)
    final coughRatio = totalEnergy > 0 ? coughEnergy / totalEnergy : 0.0;
    if (coughRatio > _coughEnergyRatio && decibelLevel > -25) {
      return (type: AudioEventType.coughing, confidence: 0.6);
    }

    // Default: ambient noise
    return (type: AudioEventType.ambientNoise, confidence: 0.5);
  }

  /// Calculate snore score (0-100) based on session events.
  /// 0 = no snoring, 100 = severe snoring throughout.
  int calculateSnoreScore({
    required List<AudioEvent> events,
    required Duration totalDuration,
  }) {
    if (events.isEmpty || totalDuration.inSeconds == 0) return 0;

    final snoreEvents =
        events.where((e) => e.type == AudioEventType.snoring).toList();
    if (snoreEvents.isEmpty) return 0;

    final totalSnoreDuration = snoreEvents.fold<Duration>(
      Duration.zero,
      (sum, e) => sum + e.duration,
    );

    // Factor 1: Percentage of time spent snoring (0-40 points)
    final snoreTimeRatio =
        totalSnoreDuration.inSeconds / totalDuration.inSeconds;
    final timeScore = (snoreTimeRatio * 100).clamp(0.0, 40.0);

    // Factor 2: Average snoring loudness (0-30 points)
    final avgDb = snoreEvents.fold(0.0, (sum, e) => sum + e.decibelLevel) /
        snoreEvents.length;
    final loudnessScore = ((avgDb + 40) / 40 * 30).clamp(0.0, 30.0);

    // Factor 3: Frequency of snore events (0-30 points)
    final eventsPerHour =
        snoreEvents.length / (totalDuration.inSeconds / 3600);
    final frequencyScore = (eventsPerHour / 60 * 30).clamp(0.0, 30.0);

    return (timeScore + loudnessScore + frequencyScore).round().clamp(0, 100);
  }

  /// Detect rhythmic snoring patterns using autocorrelation
  bool detectRhythmicPattern(List<double> amplitudes) {
    if (amplitudes.length < 20) return false;

    // Simple autocorrelation to detect periodic breathing patterns
    // Typical snoring cycle: 2-6 seconds (breathing in/out)
    final n = amplitudes.length;
    double maxCorrelation = 0;
    int bestLag = 0;

    // Check lags corresponding to 2-6 second cycles
    // At 5 samples/sec, that's lags of 10-30
    for (int lag = 10; lag < min(30, n ~/ 2); lag++) {
      double correlation = 0;
      for (int i = 0; i < n - lag; i++) {
        correlation += amplitudes[i] * amplitudes[i + lag];
      }
      correlation /= (n - lag);
      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestLag = lag;
      }
    }

    // If strong periodic pattern found, likely snoring
    final avgPower =
        amplitudes.fold(0.0, (sum, a) => sum + a * a) / amplitudes.length;
    return avgPower > 0 && maxCorrelation / avgPower > 0.3;
  }

  /// Generate Hann window coefficients for FFT
  static List<double> _hannWindow(int size) {
    return List<double>.generate(size, (i) {
      return 0.5 * (1 - cos(2 * pi * i / (size - 1)));
    });
  }
}

class AudioClassification {
  final AudioEventType type;
  final double confidence;
  final double decibelLevel;
  final double dominantFrequency;
  final List<double> frequencySpectrum;

  AudioClassification({
    required this.type,
    required this.confidence,
    required this.decibelLevel,
    required this.dominantFrequency,
    required this.frequencySpectrum,
  });
}
