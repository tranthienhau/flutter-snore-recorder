import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/sleep_provider.dart';
import '../models/sleep_session.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(isRecordingProvider);
    final sessions = ref.watch(sleepSessionsProvider);
    final recentSessions = sessions.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Snore Recorder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () => context.push('/insights'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sleep status card
            _SleepStatusCard(
              isRecording: isRecording,
              lastSession: sessions.isNotEmpty ? sessions.first : null,
            ),
            const SizedBox(height: 24),

            // Start/Stop recording button
            _RecordButton(isRecording: isRecording),
            const SizedBox(height: 24),

            // Recent nights
            if (recentSessions.isNotEmpty) ...[
              const Text(
                'Recent Nights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: recentSessions.length,
                  itemBuilder: (context, index) {
                    return _NightSummaryCard(
                      session: recentSessions[index],
                      onTap: () => context.push(
                        '/results/${recentSessions[index].id}',
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nightlight_round,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No recordings yet',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the button below to start\nrecording your sleep',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SleepStatusCard extends StatelessWidget {
  final bool isRecording;
  final SleepSession? lastSession;

  const _SleepStatusCard({required this.isRecording, this.lastSession});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (isRecording) ...[
              const Icon(Icons.mic, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Recording in progress...',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ] else if (lastSession != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Last Score',
                    value: '${lastSession!.snoreScore}',
                    color: _scoreColor(lastSession!.snoreScore),
                  ),
                  _StatItem(
                    label: 'Snore Events',
                    value: '${lastSession!.totalSnoreEvents}',
                    color: Colors.orange,
                  ),
                  _StatItem(
                    label: 'Quality',
                    value: lastSession!.quality?.label ?? 'N/A',
                    color: Colors.cyan,
                  ),
                ],
              ),
            ] else ...[
              const Icon(Icons.bedtime, color: Colors.white24, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Ready to track your sleep',
                style: TextStyle(color: Colors.white54),
              ),
            ],
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _RecordButton extends ConsumerWidget {
  final bool isRecording;

  const _RecordButton({required this.isRecording});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (isRecording) {
          context.push('/recording');
        } else {
          context.push('/recording');
        }
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRecording
                ? [Colors.red.shade700, Colors.red.shade400]
                : [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)],
          ),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red : const Color(0xFF6C63FF))
                  .withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.stop : Icons.nightlight_round,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              isRecording ? 'View Recording' : 'Start Sleep Recording',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightSummaryCard extends StatelessWidget {
  final SleepSession session;
  final VoidCallback onTap;

  const _NightSummaryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Score circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _scoreColor(session.snoreScore).withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    '${session.snoreScore}',
                    style: TextStyle(
                      color: _scoreColor(session.snoreScore),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(session.startTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timeFormat.format(session.startTime)} - '
                      '${session.endTime != null ? timeFormat.format(session.endTime!) : "..."}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session.totalSnoreEvents} snores',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(session.duration),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
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

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
