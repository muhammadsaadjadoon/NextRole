import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

class PortalStore extends ChangeNotifier {
  PortalStore({required this.demo, required this.prefs});
  final bool demo;
  final SharedPreferences prefs;
  String uid = '', role = 'candidate';
  bool dark = false, loading = true, closed = false;
  String? error;
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> jobs = [],
      applications = [],
      people = [],
      reports = [];
  final List<StreamSubscription<dynamic>> subscriptions = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  profileSubscription;
  StreamSubscription<User?>? authSubscription;
  int generation = 0, watcherGeneration = 0;
  List<Map<String, dynamic>> demoJobs = [],
      demoApplications = [],
      demoPeople = [],
      demoReports = [];
  FirebaseFirestore get db => FirebaseFirestore.instance;
  void emit() {
    if (!closed) {
      notifyListeners();
    }
  }

  Future<void> init() async {
    dark = prefs.getBool('nextrole.dark') ?? true;
    if (demo) {
      final saved = prefs.getString('nextrole.demo');
      if (saved != null) {
        try {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          demoJobs = List<Map<String, dynamic>>.from(data['jobs'] as List);
          demoApplications = List<Map<String, dynamic>>.from(
            data['applications'] as List,
          );
          demoPeople = List<Map<String, dynamic>>.from(data['people'] as List);
          demoReports = List<Map<String, dynamic>>.from(
            data['reports'] as List,
          );
        } catch (_) {
          seed();
        }
      } else {
        seed();
      }
      await switchRole('candidate');
    } else {
      authSubscription = FirebaseAuth.instance.authStateChanges().listen((u) {
        unawaited(session(u));
      });
    }
  }

  void seed() {
    demoPeople = [
      {
        'id': 'candidate',
        ...newProfile('Saadi Jadoon', 'saadi@example.com', 'candidate'),
        'headline': 'Flutter developer',
        'skills': 'Flutter, Dart, Firebase',
        'education': 'BS Computer Science · Example University',
        'experience': 'Built two Flutter projects',
        'location': 'Islamabad',
      },
      {
        'id': 'employer',
        ...newProfile('Hiring Team', 'hiring@example.com', 'employer'),
        'company': 'Orbit Studio',
        'companyApproved': true,
      },
      {
        'id': 'admin',
        ...newProfile('Workspace Admin', 'admin@example.com', 'admin'),
        'companyApproved': true,
      },
    ];
    final now = DateTime.now();
    final titles = [
      'Flutter Developer',
      'Product Designer',
      'Marketing Intern',
      'Data Analyst',
      'Business Development Associate',
      'Frontend Engineer',
    ];
    demoJobs = List.generate(
      6,
      (i) => {
        'id': 'sample$i',
        'ownerId': 'employer',
        'title': titles[i],
        'company': 'Orbit Studio',
        'location': i.isEven ? 'Islamabad' : 'Remote',
        'mode': workModes[i % 3],
        'type': i == 2 ? 'Internship' : 'Full-time',
        'field': const [
          'Engineering',
          'Design',
          'Marketing',
          'Data',
          'Business',
          'Engineering',
        ][i],
        'salary': 'PKR ${80 + i * 20}k–${120 + i * 20}k / month',
        'description':
            'DEMO LISTING. Collaborate with a small team, own meaningful work and help ship thoughtful products. This is sample data, not a real vacancy.',
        'skills': i == 0
            ? 'Flutter, Dart, Firebase'
            : 'Communication, teamwork, relevant portfolio',
        'deadline': now.add(Duration(days: 14 + i)).toIso8601String(),
        'deadlineMs': now.add(Duration(days: 14 + i)).millisecondsSinceEpoch,
        'createdAt': now.subtract(Duration(days: i)).toIso8601String(),
        'approval': 'approved',
        'open': true,
      },
    );
    demoApplications = [];
    demoReports = [];
  }

  Future<void> switchRole(String selected) async {
    if (!demo || !['candidate', 'employer', 'admin'].contains(selected)) {
      throw StateError('Demo role switching is unavailable.');
    }
    role = selected;
    uid = selected;
    refreshDemo();
    loading = false;
    emit();
  }

  void refreshDemo() {
    me = demoPeople.firstWhere((p) => p['id'] == uid);
    jobs = role == 'admin'
        ? List.of(demoJobs)
        : role == 'employer'
        ? demoJobs.where((j) => j['ownerId'] == uid).toList()
        : demoJobs
              .where((j) => j['approval'] == 'approved' && j['open'] == true)
              .toList();
    applications = demoApplications
        .where(
          (a) =>
              role == 'admin' ||
              a[role == 'employer' ? 'ownerId' : 'candidateId'] == uid,
        )
        .toList();
    people = role == 'admin' ? List.of(demoPeople) : [];
    reports = role == 'admin' ? List.of(demoReports) : [];
  }

  Future<void> persist() async {
    await prefs.setString(
      'nextrole.demo',
      jsonEncode({
        'jobs': demoJobs,
        'applications': demoApplications,
        'people': demoPeople,
        'reports': demoReports,
      }),
    );
    refreshDemo();
    emit();
  }

  Future<void> session(User? u) async {
    final g = ++generation;
    watcherGeneration++;
    final old = List<StreamSubscription<dynamic>>.of(subscriptions);
    subscriptions.clear();
    final oldProfile = profileSubscription;
    profileSubscription = null;
    me = null;
    jobs = [];
    applications = [];
    people = [];
    reports = [];
    error = null;
    uid = u?.uid ?? '';
    loading = u != null;
    emit();
    if (oldProfile != null) {
      await oldProfile.cancel();
    }
    for (final sub in old) {
      await sub.cancel();
    }
    if (u == null || closed || g != generation) {
      return;
    }
    try {
      final ref = db.collection('users').doc(uid);
      // Registration explicitly creates the profile before sign-in can load it.
      profileSubscription = ref.snapshots().listen(
        (doc) {
          if (closed || g != generation) {
            return;
          }
          if (!doc.exists) {
            me = null;
            loading = false;
            unawaited(watch(g));
            emit();
            return;
          }
          final previous = me;
          me = {'id': doc.id, ...doc.data()!};
          role = me!['role'] as String;
          loading = false;
          error = null;
          if (previous == null ||
              previous['role'] != role ||
              previous['active'] != me!['active']) {
            unawaited(watch(g));
          }
          emit();
        },
        onError: (Object e) {
          if (g == generation) {
            error = friendly(e);
            loading = false;
            emit();
          }
        },
      );
    } catch (e) {
      error = friendly(e);
      loading = false;
      emit();
    }
  }

  Future<void> watch(int g) async {
    final w = ++watcherGeneration;
    jobs = [];
    applications = [];
    people = [];
    reports = [];
    emit();
    final old = List<StreamSubscription<dynamic>>.of(subscriptions);
    subscriptions.clear();
    for (final sub in old) {
      await sub.cancel();
      if (w != watcherGeneration || closed || g != generation) {
        return;
      }
    }
    if (closed ||
        g != generation ||
        w != watcherGeneration ||
        me?['active'] != true) {
      return;
    }
    Query<Map<String, dynamic>> jq = db.collection('jobs');
    if (role == 'candidate') {
      jq = jq
          .where('approval', isEqualTo: 'approved')
          .where('open', isEqualTo: true);
    }
    if (role == 'employer') {
      jq = jq.where('ownerId', isEqualTo: uid);
    }
    listen(jq, (data) => jobs = data, g, w);
    Query<Map<String, dynamic>> aq = db.collection('applications');
    if (role != 'admin') {
      aq = aq.where(
        role == 'employer' ? 'ownerId' : 'candidateId',
        isEqualTo: uid,
      );
    }
    listen(aq, (data) => applications = data, g, w);
    if (role == 'admin') {
      listen(db.collection('users'), (data) => people = data, g, w);
      listen(db.collection('reports'), (data) => reports = data, g, w);
    }
  }

  void listen(
    Query<Map<String, dynamic>> q,
    void Function(List<Map<String, dynamic>>) assign,
    int g,
    int w,
  ) {
    subscriptions.add(
      q.snapshots().listen(
        (s) {
          if (g == generation && w == watcherGeneration && !closed) {
            assign(s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
            emit();
          }
        },
        onError: (Object e) {
          if (g == generation && w == watcherGeneration && !closed) {
            error = friendly(e);
            emit();
          }
        },
      ),
    );
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String selectedRole,
  ) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final u = credential.user!;
    await u.updateDisplayName(name);
    await db
        .collection('users')
        .doc(u.uid)
        .set(newProfile(name, email, selectedRole));
    await u.sendEmailVerification();
  }

  Future<void> repairProfile(String name, String selectedRole) async {
    final u = FirebaseAuth.instance.currentUser!;
    await db
        .collection('users')
        .doc(u.uid)
        .set(newProfile(name, u.email ?? '', selectedRole));
  }

  Future<void> profile(Map<String, dynamic> changes) async {
    if (demo) {
      me!.addAll(changes);
      await persist();
    } else {
      await db.collection('users').doc(uid).update(changes);
    }
  }

  Future<void> bookmark(String id) async {
    if (role != 'candidate') {
      throw StateError('Saved roles are for candidate accounts.');
    }
    final saved = List<String>.from(me!['saved'] as List);
    if (!saved.contains(id) && saved.length >= 300) {
      throw StateError(
        'You can save up to 300 roles. Remove a saved role first.',
      );
    }
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    await profile({'saved': saved});
  }

  Future<void> saveJob(Map<String, dynamic> job) async {
    if (me?['active'] != true ||
        !(role == 'admin' ||
            role == 'employer' && me?['companyApproved'] == true)) {
      throw StateError(
        'An active approved company or administrator is required to post a role.',
      );
    }
    if (role == 'employer' && job['ownerId'] != uid) {
      throw StateError('You can edit only your company vacancies.');
    }
    if (role == 'employer' && job['approval'] != 'pending') {
      throw StateError('Edited vacancies need administrator approval.');
    }

    if (demo) {
      final i = demoJobs.indexWhere((j) => j['id'] == job['id']);
      if (i < 0) {
        demoJobs.add(job);
      } else {
        demoJobs[i] = job;
      }
      await persist();
    } else {
      final data = Map<String, dynamic>.of(job)..remove('id');
      await db.collection('jobs').doc(job['id'] as String).set(data);
    }
  }

  Future<void> jobChange(String id, Map<String, dynamic> changes) async {
    if (demo) {
      demoJobs.firstWhere((j) => j['id'] == id).addAll(changes);
      await persist();
    } else {
      await db.collection('jobs').doc(id).update(changes);
    }
  }

  Future<void> apply(Map<String, dynamic> job, String cover) async {
    if (role != 'candidate' || me?['active'] != true) {
      throw StateError('Only active candidate accounts can apply.');
    }
    if (cover.length > 3000) {
      throw StateError('Keep your cover note within 3000 characters.');
    }
    if (!available(job)) {
      throw StateError('This vacancy is no longer accepting applications.');
    }
    final id = applicationId(job['id'] as String, uid);
    if (applications.any((a) => a['id'] == id)) {
      throw StateError('You already applied to this job.');
    }
    final record = <String, dynamic>{
      'id': id,
      'jobId': job['id'],
      'ownerId': job['ownerId'],
      'candidateId': uid,
      'jobTitle': job['title'],
      'company': job['company'],
      'name': me!['name'],
      'email': me!['email'],
      'headline': me!['headline'],
      'skills': me!['skills'],
      'education': me!['education'],
      'experience': me!['experience'],
      'cover': cover,
      'status': 'Applied',
      'createdAt': DateTime.now().toIso8601String(),
      'cvPath': '',
      'cvName': '',
    };
    if (demo) {
      demoApplications.add(record);
      await persist();
      return;
    }
    final ref = db.collection('applications').doc(id);
    if ((await ref.get()).exists) {
      throw StateError('You already applied to this job.');
    }
    record.remove('id');
    await ref.set(record);
  }

  Future<void> withdraw(String id) async {
    final a = applications.firstWhere((a) => a['id'] == id);
    if (role != 'candidate' ||
        a['candidateId'] != uid ||
        !['Applied', 'Under Review', 'Shortlisted'].contains(a['status'])) {
      throw StateError('This application cannot be withdrawn.');
    }
    if (demo) {
      a['status'] = 'Withdrawn';
      await persist();
    } else {
      await db.collection('applications').doc(id).update({
        'status': 'Withdrawn',
      });
    }
  }

  Future<void> status(String id, String value) async {
    if (me?['active'] != true ||
        !['employer', 'admin'].contains(role) ||
        (role == 'employer' && me?['companyApproved'] != true) ||
        !stages.contains(value) ||
        value == 'Withdrawn') {
      throw StateError('This decision is unavailable.');
    }
    if (applications.firstWhere((a) => a['id'] == id)['status'] ==
        'Withdrawn') {
      throw StateError('The candidate withdrew this application.');
    }
    if (demo) {
      demoApplications.firstWhere((a) => a['id'] == id)['status'] = value;
      await persist();
    } else {
      await db.collection('applications').doc(id).update({'status': value});
    }
  }

  Future<void> userChange(String id, Map<String, dynamic> changes) async {
    if (demo) {
      demoPeople.firstWhere((p) => p['id'] == id).addAll(changes);
      await persist();
    } else {
      await db.collection('users').doc(id).update(changes);
    }
  }

  Future<void> report(String jobId, String reason) async {
    final data = {
      'jobId': jobId,
      'reporterId': uid,
      'reason': reason,
      'resolved': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (demo) {
      demoReports.add({'id': const Uuid().v4(), ...data});
      await persist();
    } else {
      await db.collection('reports').add(data);
    }
  }

  Future<void> resolve(String id) async {
    if (demo) {
      demoReports.firstWhere((r) => r['id'] == id)['resolved'] = true;
      await persist();
    } else {
      await db.collection('reports').doc(id).update({'resolved': true});
    }
  }

  Future<void> theme() async {
    dark = !dark;
    await prefs.setBool('nextrole.dark', dark);
    emit();
  }

  Future<void> signOut() async {
    if (demo) {
      return;
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    closed = true;
    generation++;
    watcherGeneration++;
    unawaited(profileSubscription?.cancel());
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(authSubscription?.cancel());
    super.dispose();
  }
}

String friendly(Object e) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. Check account access, published rules and the Firebase project.';
      case 'email-already-in-use':
        return 'This email is registered. Sign in or reset your password.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'network-request-failed':
        return 'Connection failed. Check your internet and retry.';
      case 'operation-not-allowed':
        return 'Enable Email/Password in Firebase Authentication.';
      default:
        return e.message ?? 'Firebase request failed (${e.code}).';
    }
  }
  return e is StateError
      ? e.message
      : 'Could not complete this action. Please retry.';
}
