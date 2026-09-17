import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/ui/common/glass_material.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/screens/productivity/context_menu_card.dart';
import 'package:mindful/ui/screens/productivity/task_editor_sheet.dart';
import 'package:mindful/ui/screens/systems/system_widgets.dart';
import 'package:mindful/ui/screens/weekly_review/weekly_review_entry_card.dart';

import '../helpers/test_env.dart';
import '../models/life_system_test.dart' show system;

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('TaskCheckCircle', () {
    testWidgets('calls back on tap and shows the check when done',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(TaskCheckCircle(isChecked: false, onTap: () => taps++)),
      );
      await tester.tap(find.byType(TaskCheckCircle));
      expect(taps, 1);

      await tester.pumpWidget(
        wrap(TaskCheckCircle(isChecked: true, onTap: () {})),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
    });

    testWidgets('exposes its state to accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(TaskCheckCircle(isChecked: true, onTap: () {})),
      );
      expect(
        tester.getSemantics(find.byType(TaskCheckCircle)),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('GlassLayer', () {
    testWidgets('blurs the backdrop and draws a rim', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassLayer(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          child: SizedBox(width: 50, height: 50),
        ),
      ));
      expect(find.byType(BackdropFilter), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(GlassLayer),
          matching: find.byType(CustomPaint),
        ).first,
      );
      expect(paint.foregroundPainter, isA<GlassRimPainter>());
    });

    testWidgets('a transparent layer stays plain', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassLayer(
          tint: Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          child: Text('contenu'),
        ),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('contenu'), findsOneWidget);
    });

    testWidgets('a square layer has no rim to be cut', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassLayer(
          borderRadius: BorderRadius.zero,
          child: SizedBox(width: 50, height: 50),
        ),
      ));
      final paints = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(GlassLayer),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paints.any((p) => p.foregroundPainter is GlassRimPainter), isFalse);
    });

    testWidgets('blur zero draws no backdrop filter', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassSurface(blur: 0, child: SizedBox(width: 10, height: 10)),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    test('fill keeps translucent tints and softens opaque ones', () {
      final theme = ThemeData.dark();
      final translucent = Colors.red.withValues(alpha: 0.3);
      expect(GlassLayer.fillFor(theme, translucent), translucent);
      expect(GlassLayer.fillFor(theme, Colors.red).a, lessThan(1));
      expect(GlassLayer.fillFor(theme, null).a, lessThan(1));
    });

    test('rim painter repaints only when its look changes', () {
      const a = GlassRimPainter(borderRadius: BorderRadius.zero, isDark: true);
      const b = GlassRimPainter(borderRadius: BorderRadius.zero, isDark: true);
      const c = GlassRimPainter(borderRadius: BorderRadius.zero, isDark: false);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });

  group('ContextMenuCard', () {
    Future<List<String>> pumpMenu(WidgetTester tester, {int? dragData}) async {
      final tapped = <String>[];
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 200,
          child: ContextMenuCard<int>(
            dragData: dragData,
            preview: const Text('aperçu'),
            actions: [
              ContextMenuAction(
                icon: Icons.edit,
                label: 'Modifier',
                onTap: () => tapped.add('edit'),
              ),
              ContextMenuAction(
                icon: Icons.delete,
                label: 'Supprimer',
                isDestructive: true,
                onTap: () => tapped.add('delete'),
              ),
            ],
            child: const SizedBox(height: 80, child: Text('carte')),
          ),
        ),
      ));
      return tapped;
    }

    testWidgets('a long press opens the menu and an action closes it',
        (tester) async {
      final tapped = await pumpMenu(tester);
      expect(find.text('Modifier'), findsNothing);

      await tester.longPress(find.text('carte'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('aperçu'), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(tapped, ['delete']);
      expect(find.text('Modifier'), findsNothing);
    });

    testWidgets('tapping outside dismisses the menu', (tester) async {
      final tapped = await pumpMenu(tester);
      await tester.longPress(find.text('carte'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsNothing);
      expect(tapped, isEmpty);
    });

    testWidgets('draggable cards open the menu too', (tester) async {
      await pumpMenu(tester, dragData: 1);
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('carte')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);

      // Moving turns the gesture into a drag and hides the menu
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(find.text('Modifier'), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the back button closes the menu first', (tester) async {
      await pumpMenu(tester);
      await tester.longPress(find.text('carte'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsNothing);
      expect(find.text('carte'), findsOneWidget);
    });
  });

  group('system widgets', () {
    testWidgets('streak badge shows the streak length', (tester) async {
      await tester.pumpWidget(wrap(StreakBadge(
        system: system(activeDays: {dayOffset(0), dayOffset(-1)}),
      )));
      expect(find.text('2 j'), findsOneWidget);
    });

    testWidgets('chain shows one letter per day', (tester) async {
      await tester.pumpWidget(wrap(SizedBox(
        width: 300,
        child: ChainDots(system: system(activeDays: {dayOffset(0)})),
      )));
      expect(find.byType(AnimatedContainer), findsNWidgets(7));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('level ring shows the level number', (tester) async {
      await tester.pumpWidget(wrap(LevelRing(system: system(totalXp: 250))));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('progress ring hosts its child', (tester) async {
      await tester.pumpWidget(
        wrap(const ProgressRing(progress: 2, child: Text('100%'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    test('daily quote is stable for a day', () {
      expect(dailyHabitQuote(), dailyHabitQuote());
      expect(dailyHabitQuote(), isNotEmpty);
    });

    test('growth is shown as a percentage', () {
      expect(formatGrowth(1), '+0,0 %');
      expect(formatGrowth(1.051), '+5,1 %');
      expect(formatGrowth(2.7048), '+170 %');
    });
  });

  group('weekly review entry', () {
    test('Saturday and Sunday are review days', () {
      expect(WeeklyReviewEntryCard.isReviewDay(DateTime(2026, 9, 19)), isTrue);
      expect(WeeklyReviewEntryCard.isReviewDay(DateTime(2026, 9, 20)), isTrue);
      for (var day = 14; day <= 18; day++) {
        expect(
          WeeklyReviewEntryCard.isReviewDay(DateTime(2026, 9, day)),
          isFalse,
        );
      }
    });

    testWidgets('opens the review', (tester) async {
      await tester.pumpWidget(MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: WeeklyReviewEntryCard()),
          '/weeklyReview': (_) => const Scaffold(body: Text('bilan')),
        },
      ));
      expect(find.text('Bilan de la semaine'), findsOneWidget);
      await tester.tap(find.byType(WeeklyReviewEntryCard));
      await tester.pumpAndSettle();
      expect(find.text('bilan'), findsOneWidget);
    });
  });
}
