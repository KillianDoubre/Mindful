import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';

NavbarItem tab(String title, IconData icon) => NavbarItem(
      icon: icon,
      filledIcon: icon,
      titleText: title,
      sliverBody: CustomScrollView(
        slivers: [
          SliverList.builder(
            itemCount: 80,
            itemBuilder: (_, i) =>
                SizedBox(height: 60, child: Text('$title ligne $i')),
          ),
        ],
      ),
    );

Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: ScaffoldShell(
          canGoBack: false,
          items: [
            tab('Un', Icons.home),
            tab('Deux', Icons.settings),
          ],
        ),
      ),
    );

SliverAppBar headerOf(WidgetTester tester, String title) => tester.widget(
      find
          .ancestor(
            of: find.text(title),
            matching: find.byType(SliverAppBar),
          )
          .first,
    );

/// Scrolling down hides the footer; a small scroll up brings it back while
/// the page stays scrolled.
Future<void> revealFooter(WidgetTester tester, String title) async {
  await tester.drag(
    find.textContaining('$title ligne').hitTestable().first,
    const Offset(0, 120),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scrolling a tab collapses its own header', (tester) async {
    await pumpShell(tester);
    expect(headerOf(tester, 'Un').backgroundColor, Colors.transparent);

    await tester.drag(find.text('Un ligne 2'), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(headerOf(tester, 'Un').backgroundColor, isNot(Colors.transparent));
  });

  testWidgets('the tab reached from the footer starts unscrolled',
      (tester) async {
    await pumpShell(tester);
    await tester.drag(find.text('Un ligne 2'), const Offset(0, -800));
    await tester.pumpAndSettle();
    await revealFooter(tester, 'Un');

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Deux ligne 0'), findsOneWidget);
    expect(headerOf(tester, 'Deux').backgroundColor, Colors.transparent);
  });

  testWidgets('the tab reached by swiping starts unscrolled', (tester) async {
    await pumpShell(tester);
    await tester.drag(find.text('Un ligne 2'), const Offset(0, -800));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(TabBarView),
      const Offset(-500, 0),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.text('Deux ligne 0'), findsOneWidget);
    expect(headerOf(tester, 'Deux').backgroundColor, Colors.transparent);
  });

  testWidgets('scrolling one tab does not change the other', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Deux ligne 2'), const Offset(0, -800));
    await tester.pumpAndSettle();
    await revealFooter(tester, 'Deux');

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    expect(find.text('Un ligne 0'), findsOneWidget);
    expect(headerOf(tester, 'Un').backgroundColor, Colors.transparent);
  });
}
