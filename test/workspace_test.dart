import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextrole/main.dart';
import 'package:nextrole/forms.dart';
import 'package:nextrole/store.dart';

void main() {
  for (final role in ['candidate', 'employer', 'admin']) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1280, 900),
    ]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          '$role ${size.width}px text $scale navigation remains inside layout',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            SharedPreferences.setMockInitialValues({});
            final s = PortalStore(
              demo: true,
              prefs: await SharedPreferences.getInstance(),
            );
            await s.init();
            await s.switchRole(role);
            // Exercise real long strings rather than only short sample labels.
            s.me!['name'] =
                'A professional with a considerably longer display name';
            s.jobs.first['title'] =
                'Senior cross platform mobile application engineer and technical delivery lead';
            s.jobs.first['company'] =
                'International digital technology and creative product studio';
            try {
              await tester.pumpWidget(NextRole(store: s));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              for (var i = 1; i < 5; i++) {
                if (size.width >= 1000) {
                  final rail = tester.widget<NavigationRail>(
                    find.byType(NavigationRail),
                  );
                  rail.onDestinationSelected!(i);
                } else {
                  await tester.tap(find.byType(NavigationDestination).at(i));
                }
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              s.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets(
    'job and application dialogs fit a small screen and dispose cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final s = PortalStore(
        demo: true,
        prefs: await SharedPreferences.getInstance(),
      );
      await s.init();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: portalTheme(false),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => ApplyDialog(store: s, job: s.jobs.first),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await s.switchRole('employer');
        await tester.pumpWidget(
          MaterialApp(
            theme: portalTheme(false),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => JobDialog(store: s),
                  ),
                  child: const Text('Post'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Post'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        s.dispose();
      }
    },
  );
}
