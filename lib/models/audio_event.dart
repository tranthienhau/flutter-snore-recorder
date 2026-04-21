class AudioEvent {
  final DateTime timestamp;
  final Duration duration;
  final AudioEventType type;
  final double decibelLevel;
  final double confidence;
  final double dominantFrequency;
  final String? audioClipPath;

  AudioEvent({
    required this.timestamp,
    required this.duration,
    required this.type,
    required this.decibelLevel,
    this.confidence = 0.0,
    this.dominantFrequency = 0.0,
    this.audioClipPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'type': type.index,
      'decibelLevel': decibelLevel,
      'confidence': confidence,
      'dominantFrequency': dominantFrequency,
      'audioClipPath': audioClipPath,
    };
  }

  factory AudioEvent.fromJson(Map<String, dynamic> json) {
    return AudioEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      type: AudioEventType.values[json['type'] as int],
      decibelLevel: (json['decibelLevel'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      dominantFrequency:
          (json['dominantFrequency'] as num?)?.toDouble() ?? 0.0,
      audioClipPath: json['audioClipPath'] as String?,
    );
  }

  @override
  String toString() =>
      'AudioEvent(${type.label}, ${decibelLevel.toStringAsFixed(1)}dB, '
      '${duration.inSeconds}s, ${confidence.toStringAsFixed(2)} conf)';
}

enum AudioEventType {
  snoring,
  talking,
  coughing,
  silence,
  ambientNoise,
}

extension AudioEventTypeExtension on AudioEventType {
  String get label {
    switch (this) {
      case AudioEventType.snoring:
        return 'Snoring';
      case AudioEventType.talking:
        return 'Talking';
      case AudioEventType.coughing:
        return 'Coughing';
      case AudioEventType.silence:
        return 'Silence';
      case AudioEventType.ambientNoise:
        return 'Ambient Noise';
    }
  }

  /// Frequency range characteristics for each event type
  ({double minFreq, double maxFreq}) get frequencyRange {
    switch (this) {
      case AudioEventType.snoring:
        return (minFreq: 30.0, maxFreq: 500.0);
      case AudioEventType.talking:
        return (minFreq: 300.0, maxFreq: 3400.0);
      case AudioEventType.coughing:
        return (minFreq: 200.0, maxFreq: 2000.0);
      case AudioEventType.silence:
        return (minFreq: 0.0, maxFreq: 0.0);
      case AudioEventType.ambientNoise:
        return (minFreq: 20.0, maxFreq: 20000.0);
    }
  }
}
