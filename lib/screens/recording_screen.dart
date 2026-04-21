import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/sleep_provider.dart';
import '../models/audio_event.dart';
import '../widgets/waveform_painter.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startRecordingIfNeeded();
  }

  Future<void> _startRecordingIfNeeded() async {
    final isRecording = ref.read(isRecordingProvider);
    if (!isRecording) {
      final controller = ref.read(recordingControllerProvider);
      await controller.startRecording();
      _startTime = DateTime.now();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsed = DateTime.now().difference(_startTime!);
          });
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    final controller = ref.read(recordingControllerProvider);
    final session = await controller.stopRecording();
    if (mounted) {
      context.go('/results/${session.id}');
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(isRecordingProvider);
    final events = ref.watch(currentEventsProvider);
    final amplitude = ref.watch(amplitudeStreamProvider);
    final waveformSamples = ref.watch(waveformSamplesProvider);

    final currentDb = amplitude.whenOrNull(data: (db) => db) ?? -60.0;
    final latestEvent = events.isNotEmpty ? events.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // Elapsed time
          Text(
            _formatDuration(_elapsed),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),

          // Recording status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRecording) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recording',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // Real-time waveform
          Container(
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: waveformSamples.when(
                data: (samples) => CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: WaveformPainter(
                    samples: samples,
                    color: _eventColor(latestEvent?.type),
                  ),
                ),
                loading: () => CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: WaveformPainter(
                    samples: List.filled(128, 0.0),
                    color: const Color(0xFF6C63FF),
                  ),
                ),
                error: (_, __) => const Center(
                  child: Text('Audio stream error',
                      style: TextStyle(color: Colors.white38)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Decibel meter
          _DecibelMeter(decibelLevel: currentDb),
          const SizedBox(height: 24),

          // Current detection status
          if (latestEvent != null)
            _DetectionBadge(event: latestEvent),
          const SizedBox(height: 16),

          // Snore event markers (recent)
          Expanded(
            child: _EventTimeline(events: events),
          ),

          // Stop button
          Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: isRecording ? _stopRecording : null,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(isRecording ? 1.0 : 0.3),
                  boxShadow: isRecording
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ]
                      : [],
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(AudioEventType? type) {
    switch (type) {
      case AudioEventType.snoring:
        return Colors.orange;
      case AudioEventType.talking:
        return Colors.blue;
      case AudioEventType.coughing:
        return Colors.red;
      case AudioEventType.ambientNoise:
        return Colors.grey;
      default:
        return const Color(0xFF6C63FF);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _DecibelMeter extends StatelessWidget {
  final double decibelLevel;

  const _DecibelMeter({required this.decibelLevel});

  @override
  Widget build(BuildContext context) {
    // Normalize: -60dB = 0%, 0dB = 100%
    final normalized = ((decibelLevel + 60) / 60).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Volume', style: TextStyle(color: Colors.white54)),
              Text(
                '${decibelLevel.toStringAsFixed(1)} dB',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalized,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                normalized > 0.7
                    ? Colors.red
                    : normalized > 0.4
                        ? Colors.orange
                        : Colors.green,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  final AudioEvent event;

  const _DetectionBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _typeColor(event.type).withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _typeColor(event.type).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(event.type), color: _typeColor(event.type), size: 18),
          const SizedBox(width: 8),
          Text(
            '${event.type.label} detected',
            style: TextStyle(color: _typeColor(event.type)),
          ),
          const SizedBox(width: 8),
          Text(
            '${(event.confidence * 100).toInt()}%',
            style: TextStyle(
              color: _typeColor(event.type).withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(AudioEventType type) {
    switch (type) {
      case AudioEventType.snoring:
        return Colors.orange;
      case AudioEventType.talking:
        return Colors.blue;
      case AudioEventType.coughing:
        return Colors.red;
      case AudioEventType.ambientNoise:
        return Colors.grey;
      case AudioEventType.silence:
        return Colors.white24;
    }
  }

  IconData _typeIcon(AudioEventType type) {
    switch (type) {
      case AudioEventType.snoring:
        return Icons.airline_seat_flat;
      case AudioEventType.talking:
        return Icons.chat_bubble;
      case AudioEventType.coughing:
        return Icons.sick;
      case AudioEventType.ambientNoise:
        return Icons.volume_up;
      case AudioEventType.silence:
        return Icons.volume_off;
    }
  }
}

class _EventTimeline extends StatelessWidget {
  final List<AudioEvent> events;

  const _EventTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    final snoreEvents = events
        .where((e) => e.type != AudioEventType.silence)
        .toList()
        .reversed
        .take(20)
        .toList();

    if (snoreEvents.isEmpty) {
      return const Center(
        child: Text(
          'Listening for audio events...',
          style: TextStyle(color: Colors.white24),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: snoreEvents.length,
      itemBuilder: (context, index) {
        final event = snoreEvents[index];
        final time =
            '${event.timestamp.hour.toString().padLeft(2, '0')}:'
            '${event.timestamp.minute.toString().padLeft(2, '0')}:'
            '${event.timestamp.second.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Text(time,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _typeColor(event.type),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.type.label,
                style: TextStyle(color: _typeColor(event.type), fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '${event.decibelLevel.toStringAsFixed(0)} dB',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _typeColor(AudioEventType type) {
    switch (type) {
      case AudioEventType.snoring:
        return Colors.orange;
      case AudioEventType.talking:
        return Colors.blue;
      case AudioEventType.coughing:
        return Colors.red;
      case AudioEventType.ambientNoise:
        return Colors.grey;
      case AudioEventType.silence:
        return Colors.white24;
    }
  }
}
