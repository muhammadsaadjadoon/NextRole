import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextrole/store.dart';

void main() {
  test(
    'demo hiring workflow persists application and employer decision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = PortalStore(demo: true, prefs: prefs);
      await s.init();
      final job = s.jobs.first;
      await s.apply(job, 'Hello');
      expect(s.applications.single['status'], 'Applied');
      await expectLater(s.apply(job, ''), throwsStateError);
      await s.switchRole('employer');
      await s.status(s.applications.single['id'] as String, 'Shortlisted');
      await s.switchRole('candidate');
      expect(s.applications.single['status'], 'Shortlisted');
      s.dispose();
      final restored = PortalStore(demo: true, prefs: prefs);
      await restored.init();
      expect(restored.applications.single['status'], 'Shortlisted');
      restored.dispose();
    },
  );
  test('withdrawal persists and cannot be reversed by employer', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = PortalStore(demo: true, prefs: prefs);
    await s.init();
    await s.apply(s.jobs.first, 'My profile fits this opportunity.');
    final id = s.applications.single['id'] as String;
    await s.withdraw(id);
    expect(s.applications.single['status'], 'Withdrawn');
    await s.switchRole('employer');
    await expectLater(s.status(id, 'Selected'), throwsStateError);
    await expectLater(s.apply(s.jobs.first, ''), throwsStateError);
    s.dispose();
    final restored = PortalStore(demo: true, prefs: prefs);
    await restored.init();
    expect(restored.applications.single['status'], 'Withdrawn');
    restored.dispose();
  });
  test('bookmark cap and unapproved employer are guarded', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PortalStore(
      demo: true,
      prefs: await SharedPreferences.getInstance(),
    );
    await s.init();
    s.me!['saved'] = List.generate(300, (i) => 'job$i');
    await expectLater(s.bookmark('extra'), throwsStateError);
    await s.switchRole('employer');
    s.me!['companyApproved'] = false;
    await expectLater(
      s.saveJob({...s.jobs.first, 'approval': 'pending'}),
      throwsStateError,
    );
    s.dispose();
  });
}
