import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_snore_recorder/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  setUpAll(() async {
    await Hive.initFlutter();
    final sessionsBox = await Hive.openBox('sleep_sessions');
    final remediesBox = await Hive.openBox('remedies');
    await sessionsBox.clear();
    await remediesBox.clear();

    // Seed several nights of realistic snore-tracking data.
    final now = DateTime(2026, 6, 11, 23, 30);
    final mock = <Map<String, dynamic>>[];
    final scores = [18, 34, 52, 41, 67, 29, 22];
    final snoreCounts = [12, 38, 71, 55, 96, 27, 19];
    for (var i = 0; i < scores.length; i++) {
      final start = now.subtract(Duration(days: i));
      final end = start.add(const Duration(hours: 7, minutes: 20));
      final events = <Map<String, dynamic>>[];
      for (var e = 0; e < 6; e++) {
        events.add({
          'timestamp':
              start.add(Duration(minutes: 40 + e * 55)).toIso8601String(),
          'duration': (8 + e * 3) * 1000,
          'type': e % 3 == 0 ? 0 : (e % 3 == 1 ? 1 : 2),
          'decibelLevel': 42.0 + e * 6,
          'confidence': 0.7 + e * 0.03,
          'dominantFrequency': 90.0 + e * 25,
        });
      }
      mock.add({
        'id': 'night-$i',
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'duration': const Duration(hours: 7, minutes: 20).inSeconds,
        'events': events,
        'snoreScore': scores[i],
        'averageDecibel': 46.0 + i * 2,
        'maxDecibel': 72.0 + i,
        'totalSnoreEvents': snoreCounts[i],
        'totalSnoreDuration': (snoreCounts[i] * 9),
        'audioSegmentPaths': const [],
        'quality': scores[i] <= 20
            ? 0
            : scores[i] <= 40
                ? 1
                : scores[i] <= 65
                    ? 2
                    : 3,
      });
    }
    for (final s in mock) {
      await sessionsBox.put(s['id'], jsonEncode(s));
    }
  });

  testWidgets('capture snore recorder flow', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SnoreRecorderApp()));
    await tester.pumpAndSettle();
    await shoot(tester, '01-home');

    // History (chevron / history icon in app bar).
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await shoot(tester, '02-history');

    // Back to home.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Insights.
    await tester.tap(find.byIcon(Icons.insights));
    await tester.pumpAndSettle();
    await shoot(tester, '03-insights');

    // Back to home, then open a night report.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    final firstNight = find.byType(InkWell).first;
    await tester.tap(firstNight);
    await tester.pumpAndSettle();
    await shoot(tester, '04-report');
  });
}
