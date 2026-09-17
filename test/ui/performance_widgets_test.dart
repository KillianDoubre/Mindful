import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/ui/common/glass_material.dart';
import 'package:mindful/ui/common/page_app_bar.dart';
import 'package:mindful/ui/common/sliver_distracting_apps_list.dart';

void main() {
  group('positionsInGroup', () {
    test('empty and single groups', () {
      expect(positionsInGroup([]), isEmpty);
      expect(positionsInGroup(['a']), {'a': ItemPosition.none});
    });

    test('first, middle and last tiles', () {
      expect(positionsInGroup(['a', 'b', 'c', 'd']), {
        'a': ItemPosition.top,
        'b': ItemPosition.mid,
        'c': ItemPosition.mid,
        'd': ItemPosition.bottom,
      });
      expect(positionsInGroup(['a', 'b']), {
        'a': ItemPosition.top,
        'b': ItemPosition.bottom,
      });
    });

    test('stays fast on long lists', () {
      final apps = [for (var i = 0; i < 20000; i++) 'app$i'];
      final watch = Stopwatch()..start();
      final positions = positionsInGroup(apps);
      watch.stop();
      expect(positions, hasLength(20000));
      expect(watch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('GlassScope', () {
    testWidgets('turns the blur off below it', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: GlassScope(
          child: GlassLayer(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('blur stays on outside a scope or when allowed',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: GlassScope(
          blur: true,
          child: GlassLayer(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    test('notifies only when the setting changes', () {
      const off = GlassScope(child: SizedBox());
      const on = GlassScope(blur: true, child: SizedBox());
      expect(off.updateShouldNotify(const GlassScope(child: SizedBox())), isFalse);
      expect(off.updateShouldNotify(on), isTrue);
    });
  });

  group('PageAppBar', () {
    testWidgets('is transparent until content scrolls under it',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: const PageAppBar(title: Text('Titre')),
          body: ListView(
            children: [for (var i = 0; i < 60; i++) Text('ligne $i')],
          ),
        ),
      ));
      final theme = Theme.of(tester.element(find.byType(ListView)));
      Color barColor() => tester
          .widget<Material>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            ).first,
          )
          .color!;

      expect(barColor(), Colors.transparent);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(barColor(), pageHeaderColor(theme));
    });

    test('header colour is the neutral page background', () {
      final theme = ThemeData.dark();
      final color = pageHeaderColor(theme);
      expect(color.r, theme.scaffoldBackgroundColor.r);
      expect(color.g, theme.scaffoldBackgroundColor.g);
      expect(color.b, theme.scaffoldBackgroundColor.b);
      expect(color.a, lessThan(1));
    });

    test('reports the height of its bottom widget', () {
      const bar = PageAppBar(
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6),
          child: SizedBox(),
        ),
      );
      expect(bar.preferredSize.height, kToolbarHeight + 6);
      expect(const PageAppBar().preferredSize.height, kToolbarHeight);
    });
  });
}
