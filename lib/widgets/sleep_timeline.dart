import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audio_event.dart';

/// Timeline widget showing tagged audio events through the night.
/// Displays a horizontal scrollable timeline with color-coded event markers.
class SleepTimeline extends StatelessWidget {
  final List<AudioEvent> events;
  final DateTime startTime;
  final DateTime endTime;

  const SleepTimeline({
    super.key,
    required this.events,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final totalDuration = endTime.difference(startTime);
    if (totalDuration.inSeconds <= 0) {
      return const Center(
        child: Text('No timeline data', style: TextStyle(color: Colors.white38)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            _Legend(),
            const SizedBox(height: 12),

            // Timeline bar
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(
                        constraints.maxWidth,
                        totalDuration.inMinutes * 2.0,
                      ),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, 100),
                        painter: _TimelinePainter(
                          events: events,
                          startTime: startTime,
                          endTime: endTime,
                          totalDuration: totalDuration,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Time labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('h:mm a').format(startTime),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                if (totalDuration.inHours > 2)
                  Text(
                    DateFormat('h:mm a').format(
                      startTime.add(totalDuration ~/ 2),
                    ),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                Text(
                  DateFormat('h:mm a').format(endTime),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.orange, label: 'Snore'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.blue, label: 'Talk'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.red, label: 'Cough'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.grey, label: 'Noise'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<AudioEvent> events;
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;

  _TimelinePainter({
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Draw background track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.4),
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, bgPaint);

    // Draw hour markers
    final markerPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final hours = totalDuration.inHours;
    for (int i = 1; i < hours; i++) {
      final x = (i / hours) * size.width;
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        markerPaint,
      );
    }

    // Draw events
    for (final event in events) {
      if (event.type == AudioEventType.silence) continue;

      final eventStart = event.timestamp.difference(startTime);
      final xStart = (eventStart.inSeconds / totalDuration.inSeconds) *
          size.width;
      final eventWidth =
          (event.duration.inSeconds / totalDuration.inSeconds) * size.width;

      final color = _eventColor(event.type);

      // Event bar
      final barPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      final barHeight = size.height * 0.3 *
          ((event.decibelLevel + 60) / 60).clamp(0.2, 1.0);
      final barY = size.height * 0.5 - barHeight / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            xStart.clamp(0, size.width),
            barY,
            eventWidth.clamp(2, size.width),
            barHeight,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );

      // Event dot on top
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(
          (xStart + eventWidth / 2).clamp(0, size.width),
          size.height * 0.2,
        ),
        3,
        dotPaint,
      );
    }
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
        return Colors.transparent;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.events != events;
  }
}
