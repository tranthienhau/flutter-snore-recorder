import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/sleep_session.dart';
import '../providers/sleep_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sleepSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'No sleep data yet',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Snore score trend chart
                  const Text(
                    'Snore Score Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: _ScoreTrendChart(sessions: sessions),
                  ),
                  const SizedBox(height: 24),

                  // Sleep duration chart
                  const Text(
                    'Sleep Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: _DurationChart(sessions: sessions),
                  ),
                  const SizedBox(height: 24),

                  // Summary stats
                  _SummaryStats(sessions: sessions),
                  const SizedBox(height: 24),

                  // Session list
                  const Text(
                    'All Nights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sessions.map((session) => _SessionListItem(
                        session: session,
                        onTap: () => context.push('/results/${session.id}'),
                      )),
                ],
              ),
            ),
    );
  }
}

class _ScoreTrendChart extends StatelessWidget {
  final List<SleepSession> sessions;

  const _ScoreTrendChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final reversed = sessions.reversed.take(14).toList();
    if (reversed.isEmpty) return const SizedBox.shrink();

    final spots = reversed.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.snoreScore.toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white12,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= reversed.length) return const SizedBox();
                    return Text(
                      DateFormat('M/d').format(reversed[idx].startTime),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 9),
                    );
                  },
                  interval: (reversed.length / 5).ceilToDouble(),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF6C63FF),
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3,
                    color: _scoreColor(spot.y.toInt()),
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                ),
              ),
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
}

class _DurationChart extends StatelessWidget {
  final List<SleepSession> sessions;

  const _DurationChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final reversed = sessions.reversed.take(14).toList();
    if (reversed.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.white12,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}h',
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= reversed.length) return const SizedBox();
                    return Text(
                      DateFormat('M/d').format(reversed[idx].startTime),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 9),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: reversed.asMap().entries.map((entry) {
              final hours =
                  (entry.value.duration?.inMinutes ?? 0) / 60.0;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: hours,
                    color: Colors.cyan.withOpacity(0.8),
                    width: 12,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SummaryStats extends StatelessWidget {
  final List<SleepSession> sessions;

  const _SummaryStats({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final avgScore = sessions.isNotEmpty
        ? sessions.fold(0, (sum, s) => sum + s.snoreScore) ~/ sessions.length
        : 0;

    final avgDuration = sessions.isNotEmpty
        ? Duration(
            seconds: sessions
                    .fold(0, (sum, s) => sum + (s.duration?.inSeconds ?? 0)) ~/
                sessions.length)
        : Duration.zero;

    final totalSnoreEvents =
        sessions.fold(0, (sum, s) => sum + s.totalSnoreEvents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Statistics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn('Avg Score', '$avgScore'),
                _StatColumn('Nights', '${sessions.length}'),
                _StatColumn('Avg Sleep',
                    '${avgDuration.inHours}h ${avgDuration.inMinutes % 60}m'),
                _StatColumn('Total Snores', '$totalSnoreEvents'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final SleepSession session;
  final VoidCallback onTap;

  const _SessionListItem({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _scoreColor(session.snoreScore).withOpacity(0.2),
          child: Text(
            '${session.snoreScore}',
            style: TextStyle(
              color: _scoreColor(session.snoreScore),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          DateFormat('EEE, MMM d, yyyy').format(session.startTime),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${session.totalSnoreEvents} snore events, '
          '${_formatDuration(session.duration)}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score <= 20) return Colors.green;
    if (score <= 40) return Colors.lightGreen;
    if (score <= 65) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}
