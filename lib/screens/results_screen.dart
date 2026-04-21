import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/audio_event.dart';
import '../models/sleep_session.dart';
import '../providers/sleep_provider.dart';
import '../widgets/sleep_timeline.dart';

class ResultsScreen extends ConsumerWidget {
  final String sessionId;

  const ResultsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session =
        ref.watch(sleepSessionsProvider.notifier).getSession(sessionId);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: const Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Report'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Snore score header
            _ScoreCard(session: session),
            const SizedBox(height: 20),

            // Sleep quality metrics
            _MetricsRow(session: session),
            const SizedBox(height: 20),

            // Timeline with tagged events
            const Text(
              'Sleep Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SleepTimeline(
                events: session.events,
                startTime: session.startTime,
                endTime: session.endTime ?? DateTime.now(),
              ),
            ),
            const SizedBox(height: 20),

            // Event breakdown
            _EventBreakdown(events: session.events),
            const SizedBox(height: 20),

            // Audio playback section
            _AudioPlaybackSection(session: session),
            const SizedBox(height: 20),

            // Sleep metrics
            _SleepMetricsCard(session: session),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final SleepSession session;

  const _ScoreCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Score circle
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: session.snoreScore / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        _scoreColor(session.snoreScore),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${session.snoreScore}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(session.snoreScore),
                        ),
                      ),
                      const Text(
                        'Score',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.quality?.label ?? 'N/A',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor(session.snoreScore),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(session.startTime),
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('h:mm a').format(session.startTime)} - '
                    '${session.endTime != null ? DateFormat('h:mm a').format(session.endTime!) : "..."}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score <= 20) return Colors.green;
    if (score <= 40) return Colors.lightGreen;
    if (score <= 65) return Colors.orange;
    return Colors.red;
  }
}

class _MetricsRow extends StatelessWidget {
  final SleepSession session;

  const _MetricsRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.access_time,
            label: 'Duration',
            value: _formatDuration(session.duration),
            color: Colors.cyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.airline_seat_flat,
            label: 'Snore Events',
            value: '${session.totalSnoreEvents}',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.volume_up,
            label: 'Max dB',
            value: '${session.maxDecibel.toStringAsFixed(0)}',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBreakdown extends StatelessWidget {
  final List<AudioEvent> events;

  const _EventBreakdown({required this.events});

  @override
  Widget build(BuildContext context) {
    final grouped = <AudioEventType, int>{};
    for (final event in events) {
      grouped[event.type] = (grouped[event.type] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...grouped.entries.map((entry) {
              final percentage =
                  events.isNotEmpty ? entry.value / events.length : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _eventColor(entry.key),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key.label,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.value} (${(percentage * 100).toInt()}%)',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _eventColor(AudioEventType type) {
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

class _AudioPlaybackSection extends StatelessWidget {
  final SleepSession session;

  const _AudioPlaybackSection({required this.session});

  @override
  Widget build(BuildContext context) {
    final snoreClips = session.events
        .where((e) =>
            e.type == AudioEventType.snoring && e.audioClipPath != null)
        .take(5)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Snore Clips',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (snoreClips.isEmpty)
              const Text(
                'No individual snore clips saved for this session.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              )
            else
              ...snoreClips.map((clip) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle, color: Colors.orange),
                  title: Text(
                    DateFormat('h:mm:ss a').format(clip.timestamp),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  subtitle: Text(
                    '${clip.decibelLevel.toStringAsFixed(0)} dB, '
                    '${clip.duration.inSeconds}s',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                );
              }),
            if (session.audioSegmentPaths.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.audiotrack, color: Color(0xFF6C63FF)),
                title: const Text(
                  'Full Recording',
                  style: TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  _formatDuration(session.duration),
                  style: const TextStyle(color: Colors.white38),
                ),
                trailing:
                    const Icon(Icons.play_arrow, color: Color(0xFF6C63FF)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }
}

class _SleepMetricsCard extends StatelessWidget {
  final SleepSession session;

  const _SleepMetricsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final snoreDur = session.totalSnoreDuration;
    final totalDur = session.duration ?? const Duration(hours: 1);
    final snorePercent = totalDur.inSeconds > 0
        ? (snoreDur.inSeconds / totalDur.inSeconds * 100)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Quality Metrics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _MetricRow('Avg Volume', '${session.averageDecibel.toStringAsFixed(1)} dB'),
            _MetricRow('Peak Volume', '${session.maxDecibel.toStringAsFixed(1)} dB'),
            _MetricRow('Snore Time', '${snoreDur.inMinutes}m (${snorePercent.toStringAsFixed(0)}%)'),
            _MetricRow('Total Events', '${session.events.length}'),
            _MetricRow('Sleep Quality', session.quality?.label ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
