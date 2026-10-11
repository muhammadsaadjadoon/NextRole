import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextrole/live_jobs.dart';

Map<String, dynamic> record() => {
  'slug': 'real-role',
  'title': 'Flutter developer',
  'company_name': 'Example company',
  'description':
      '<p>Build <strong>apps</strong> &amp; learn.</p><script>bad()</script>',
  'remote': true,
  'location': 'Berlin',
  'url': 'https://www.arbeitnow.com/view/real-role',
  'tags': ['Flutter'],
  'job_types': ['full_time'],
  'created_at': 1700000000,
};
void main() {
  test('provider record is decoded and active HTML is never rendered', () {
    final job = PublicJob.parse(record())!;
    expect(job.description, contains('Build apps & learn.'));
    expect(job.description, isNot(contains('bad()')));
    expect(job.remote, true);
    expect(job.created!.year, 2023);
    expect(
      PublicJob.parse({...record(), 'url': 'javascript:alert(1)'}),
      isNull,
    );
    expect(sourceUrl('https://arbeitnow.com.attacker.com/job'), isNull);
  });
  test(
    'fetch deduplicates, caches and avoids repeated startup requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'data': [record(), record()],
          }),
          200,
        );
      });
      final feed = PublicJobsFeed(prefs: prefs, client: client);
      await feed.initialize();
      expect(feed.jobs.length, 1);
      expect(calls, 1);
      await feed.refresh();
      expect(calls, 1);
      await feed.refresh(manual: true);
      expect(calls, 1);
      expect(feed.error, contains('five minutes'));
      feed.dispose();
      final restored = PublicJobsFeed(
        prefs: prefs,
        client: MockClient((_) async {
          throw StateError('fresh cache must not request');
        }),
      );
      await restored.initialize();
      expect(restored.jobs.length, 1);
      expect(restored.error, isNull);
      restored.dispose();
    },
  );
  test('failed refresh preserves cached listings and reports error', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026);
    var fail = false;
    final feed = PublicJobsFeed(
      prefs: prefs,
      clock: () => now,
      client: MockClient(
        (_) async => fail
            ? http.Response('unavailable', 503)
            : http.Response(
                jsonEncode({
                  'data': [record()],
                }),
                200,
              ),
      ),
    );
    await feed.initialize();
    now = now.add(const Duration(hours: 7));
    fail = true;
    await feed.refresh();
    expect(feed.jobs.length, 1);
    expect(feed.error, contains('503'));
    feed.dispose();
  });
  test('external saves persist locally without Firebase writes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final feed = PublicJobsFeed(
      prefs: prefs,
      client: MockClient((_) async => http.Response('{"data":[]}', 200)),
    );
    await feed.initialize();
    await feed.toggleSaved('real-role');
    expect(prefs.getStringList('nextrole.publicJobs.saved'), ['real-role']);
    await feed.toggleSaved('real-role');
    expect(feed.saved, isEmpty);
    feed.dispose();
  });
  test('malformed response does not manufacture vacancies', () async {
    SharedPreferences.setMockInitialValues({});
    final feed = PublicJobsFeed(
      prefs: await SharedPreferences.getInstance(),
      client: MockClient(
        (_) async => http.Response('{"data":[{"title":"fake"}]}', 200),
      ),
    );
    await feed.initialize();
    expect(feed.jobs, isEmpty);
    expect(feed.error, isNotNull);
    feed.dispose();
  });
}
