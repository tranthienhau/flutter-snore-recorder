import 'audio_event.dart';

class SleepSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final List<AudioEvent> events;
  final int snoreScore;
  final double averageDecibel;
  final double maxDecibel;
  final int totalSnoreEvents;
  final Duration totalSnoreDuration;
  final List<String> audioSegmentPaths;
  final Map<String, dynamic>? remedies;
  final SleepQuality? quality;

  SleepSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    this.events = const [],
    this.snoreScore = 0,
    this.averageDecibel = 0.0,
    this.maxDecibel = 0.0,
    this.totalSnoreEvents = 0,
    this.totalSnoreDuration = Duration.zero,
    this.audioSegmentPaths = const [],
    this.remedies,
    this.quality,
  });

  SleepSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    List<AudioEvent>? events,
    int? snoreScore,
    double? averageDecibel,
    double? maxDecibel,
    int? totalSnoreEvents,
    Duration? totalSnoreDuration,
    List<String>? audioSegmentPaths,
    Map<String, dynamic>? remedies,
    SleepQuality? quality,
  }) {
    return SleepSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      events: events ?? this.events,
      snoreScore: snoreScore ?? this.snoreScore,
      averageDecibel: averageDecibel ?? this.averageDecibel,
      maxDecibel: maxDecibel ?? this.maxDecibel,
      totalSnoreEvents: totalSnoreEvents ?? this.totalSnoreEvents,
      totalSnoreDuration: totalSnoreDuration ?? this.totalSnoreDuration,
      audioSegmentPaths: audioSegmentPaths ?? this.audioSegmentPaths,
      remedies: remedies ?? this.remedies,
      quality: quality ?? this.quality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inSeconds,
      'events': events.map((e) => e.toJson()).toList(),
      'snoreScore': snoreScore,
      'averageDecibel': averageDecibel,
      'maxDecibel': maxDecibel,
      'totalSnoreEvents': totalSnoreEvents,
      'totalSnoreDuration': totalSnoreDuration.inSeconds,
      'audioSegmentPaths': audioSegmentPaths,
      'remedies': remedies,
      'quality': quality?.index,
    };
  }

  factory SleepSession.fromJson(Map<String, dynamic> json) {
    return SleepSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => AudioEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      snoreScore: json['snoreScore'] as int? ?? 0,
      averageDecibel: (json['averageDecibel'] as num?)?.toDouble() ?? 0.0,
      maxDecibel: (json['maxDecibel'] as num?)?.toDouble() ?? 0.0,
      totalSnoreEvents: json['totalSnoreEvents'] as int? ?? 0,
      totalSnoreDuration:
          Duration(seconds: json['totalSnoreDuration'] as int? ?? 0),
      audioSegmentPaths:
          (json['audioSegmentPaths'] as List<dynamic>?)?.cast<String>() ?? [],
      remedies: json['remedies'] as Map<String, dynamic>?,
      quality: json['quality'] != null
          ? SleepQuality.values[json['quality'] as int]
          : null,
    );
  }
}

enum SleepQuality {
  excellent,
  good,
  fair,
  poor,
}

extension SleepQualityExtension on SleepQuality {
  String get label {
    switch (this) {
      case SleepQuality.excellent:
        return 'Excellent';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.poor:
        return 'Poor';
    }
  }

  double get scoreThreshold {
    switch (this) {
      case SleepQuality.excellent:
        return 20;
      case SleepQuality.good:
        return 40;
      case SleepQuality.fair:
        return 65;
      case SleepQuality.poor:
        return 100;
    }
  }
}
