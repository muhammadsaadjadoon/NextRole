import 'package:flutter_test/flutter_test.dart';
import 'package:nextrole/models.dart';

void main() {
  Map<String, dynamic> job({
    bool open = true,
    String approval = 'approved',
    int days = 1,
  }) => {
    'title': 'Flutter Developer',
    'company': 'Orbit',
    'skills': 'Dart',
    'description': 'Build apps',
    'location': 'Islamabad',
    'type': 'Full-time',
    'mode': 'Remote',
    'field': 'Engineering',
    'createdAt': DateTime.now().toIso8601String(),
    'deadline': DateTime.now().add(Duration(days: days)).toIso8601String(),
    'open': open,
    'approval': approval,
  };
  test('pending, closed and expired jobs are unavailable', () {
    expect(available(job(approval: 'pending')), false);
    expect(available(job(open: false)), false);
    expect(available(job(days: -1)), false);
  });
  test('search and filters intersect', () {
    final data = [job()];
    expect(
      filterJobs(
        data,
        search: 'dart',
        mode: 'Remote',
        location: 'islam',
      ).length,
      1,
    );
    expect(filterJobs(data, type: 'Internship'), isEmpty);
  });
  test('application IDs prevent duplicate job-user pairs', () {
    expect(applicationId('job', 'user'), 'job_user');
  });
  test('new employers cannot approve themselves', () {
    final p = newProfile('Saadi', 'saadi@example.com', 'employer');
    expect(p['companyApproved'], false);
    expect(p['active'], true);
  });
  test('profile readiness and skill relevance use supplied details only', () {
    final p = newProfile('Saadi', 's@example.com', 'candidate');
    expect(profileCompletion(p), 17);
    p.addAll({
      'headline': 'Developer',
      'location': 'Islamabad',
      'skills': 'Flutter, Dart, Flutter',
      'education': 'BS',
      'experience': 'Projects',
    });
    expect(profileCompletion(p), 100);
    expect(skillMatches({'skills': 'Flutter and Dart'}, p), 2);
  });
}
