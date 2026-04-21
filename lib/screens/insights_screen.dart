import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sleep_session.dart';
import '../providers/sleep_provider.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _availableRemedies = [
    'Nose Strip',
    'Side Sleeping',
    'Elevated Pillow',
    'No Alcohol',
    'Humidifier',
    'Mouth Tape',
    'Weight Exercise',
    'Nasal Spray',
  ];

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sleepSessionsProvider);
    final remedies = ref.watch(remediesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key insights
            _InsightsSummary(sessions: sessions),
            const SizedBox(height: 24),

            // Remedies tracking
            const Text(
              'Remedies Tracking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track what remedies you use each night to find what works best for reducing snoring.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _RemediesGrid(
              remedies: _availableRemedies,
              onToggle: (remedy, used) {
                final latestSession =
                    sessions.isNotEmpty ? sessions.first : null;
                if (latestSession != null) {
                  ref.read(remediesProvider.notifier).addRemedy(
                        latestSession.id,
                        remedy,
                        used,
                      );
                }
              },
            ),
            const SizedBox(height: 24),

            // Correlation analysis
            const Text(
              'Correlation Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _CorrelationChart(
              sessions: sessions,
              remedyData: remedies,
            ),
            const SizedBox(height: 24),

            // Factors comparison
            _FactorsComparison(sessions: sessions),
          ],
        ),
      ),
    );
  }
}

class _InsightsSummary extends StatelessWidget {
  final List<SleepSession> sessions;

  const _InsightsSummary({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: Colors.white24, size: 32),
              const SizedBox(height: 12),
              Text(
                'Record at least 2 nights to see insights',
                style: TextStyle(color: Colors.white38),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final insights = _generateInsights(sessions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Key Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        insight.isPositive
                            ? Icons.trending_down
                            : Icons.trending_up,
                        color:
                            insight.isPositive ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight.text,
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  List<_Insight> _generateInsights(List<SleepSession> sessions) {
    final insights = <_Insight>[];
    final recent = sessions.take(7).toList();
    final older = sessions.skip(7).take(7).toList();

    // Trend analysis
    if (recent.length >= 3) {
      final recentAvg =
          recent.fold(0, (s, r) => s + r.snoreScore) / recent.length;
      final firstAvg = recent.last.snoreScore;

      if (recentAvg < firstAvg * 0.8) {
        insights.add(_Insight(
          text:
              'Your snore score has improved by ${((1 - recentAvg / firstAvg) * 100).toInt()}% recently.',
          isPositive: true,
        ));
      } else if (recentAvg > firstAvg * 1.2) {
        insights.add(_Insight(
          text:
              'Your snoring has increased by ${((recentAvg / firstAvg - 1) * 100).toInt()}% recently. Consider trying new remedies.',
          isPositive: false,
        ));
      }
    }

    // Sleep duration insight
    if (recent.isNotEmpty) {
      final avgDuration = recent.fold<int>(
              0, (s, r) => s + (r.duration?.inMinutes ?? 0)) /
          recent.length;
      if (avgDuration < 360) {
        insights.add(_Insight(
          text:
              'Average sleep duration is ${(avgDuration / 60).toStringAsFixed(1)}h. Aim for 7-9 hours for better sleep quality.',
          isPositive: false,
        ));
      }
    }

    // Worst night analysis
    if (recent.isNotEmpty) {
      final worst = recent.reduce((a, b) =>
          a.snoreScore > b.snoreScore ? a : b);
      if (worst.snoreScore > 60) {
        final day = _dayOfWeek(worst.startTime.weekday);
        insights.add(_Insight(
          text: 'Worst night was $day with a score of ${worst.snoreScore}.',
          isPositive: false,
        ));
      }
    }

    if (insights.isEmpty) {
      insights.add(_Insight(
        text: 'Keep tracking to discover patterns in your sleep.',
        isPositive: true,
      ));
    }

    return insights;
  }

  String _dayOfWeek(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}

class _Insight {
  final String text;
  final bool isPositive;

  _Insight({required this.text, required this.isPositive});
}

class _RemediesGrid extends StatefulWidget {
  final List<String> remedies;
  final void Function(String remedy, bool used) onToggle;

  const _RemediesGrid({required this.remedies, required this.onToggle});

  @override
  State<_RemediesGrid> createState() => _RemediesGridState();
}

class _RemediesGridState extends State<_RemediesGrid> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.remedies.map((remedy) {
        final isSelected = _selected.contains(remedy);
        return FilterChip(
          label: Text(remedy),
          selected: isSelected,
          selectedColor: const Color(0xFF6C63FF).withOpacity(0.3),
          checkmarkColor: const Color(0xFF6C63FF),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.white54,
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white12,
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selected.add(remedy);
              } else {
                _selected.remove(remedy);
              }
            });
            widget.onToggle(remedy, selected);
          },
        );
      }).toList(),
    );
  }
}

class _CorrelationChart extends StatelessWidget {
  final List<SleepSession> sessions;
  final Map<String, List<RemedyEntry>> remedyData;

  const _CorrelationChart({
    required this.sessions,
    required this.remedyData,
  });

  @override
  Widget build(BuildContext context) {
    if (remedyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Track remedies for at least a few nights to see correlations.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Build correlation data: average snore score with vs without each remedy
    final correlations = <String, ({double withRemedy, double withoutRemedy})>{};

    for (final entry in remedyData.entries) {
      final remedy = entry.key;
      final entries = entry.value;

      final usedSessionIds =
          entries.where((e) => e.used).map((e) => e.sessionId).toSet();

      final withRemedySessions = sessions
          .where((s) => usedSessionIds.contains(s.id))
          .toList();
      final withoutRemedySessions = sessions
          .where((s) => !usedSessionIds.contains(s.id))
          .toList();

      if (withRemedySessions.isNotEmpty && withoutRemedySessions.isNotEmpty) {
        final avgWith = withRemedySessions
                .fold(0, (s, r) => s + r.snoreScore) /
            withRemedySessions.length;
        final avgWithout = withoutRemedySessions
                .fold(0, (s, r) => s + r.snoreScore) /
            withoutRemedySessions.length;

        correlations[remedy] = (
          withRemedy: avgWith,
          withoutRemedy: avgWithout,
        );
      }
    }

    if (correlations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Not enough data to show correlations yet.',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: correlations.entries.map((entry) {
            final diff = entry.value.withoutRemedy - entry.value.withRemedy;
            final isEffective = diff > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    isEffective ? Icons.check_circle : Icons.remove_circle,
                    color: isEffective ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Text(
                    isEffective
                        ? '-${diff.toStringAsFixed(0)} points'
                        : '+${(-diff).toStringAsFixed(0)} points',
                    style: TextStyle(
                      color: isEffective ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FactorsComparison extends StatelessWidget {
  final List<SleepSession> sessions;

  const _FactorsComparison({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.length < 7) {
      return const SizedBox.shrink();
    }

    // Compare weekday vs weekend snoring
    final weekdayScores = sessions
        .where((s) => s.startTime.weekday <= 5)
        .map((s) => s.snoreScore)
        .toList();
    final weekendScores = sessions
        .where((s) => s.startTime.weekday > 5)
        .map((s) => s.snoreScore)
        .toList();

    final avgWeekday = weekdayScores.isNotEmpty
        ? weekdayScores.reduce((a, b) => a + b) / weekdayScores.length
        : 0.0;
    final avgWeekend = weekendScores.isNotEmpty
        ? weekendScores.reduce((a, b) => a + b) / weekendScores.length
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekday vs Weekend',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value == 0 ? 'Weekday' : 'Weekend',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: avgWeekday,
                          color: const Color(0xFF6C63FF),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: avgWeekend,
                          color: Colors.cyan,
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
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
