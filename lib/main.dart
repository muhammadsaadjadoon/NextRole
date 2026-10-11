import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'store.dart';
import 'forms.dart';
import 'ui.dart';
import 'live_jobs.dart';
import 'firebase_options.dart';
export 'ui.dart' show ink, accent;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO');
  try {
    if (!demo) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final store = PortalStore(
      demo: demo,
      prefs: await SharedPreferences.getInstance(),
    );
    await store.init();
    runApp(NextRole(store: store));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      const Icon(Icons.settings_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Connect your NextRole workspace',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        '${friendly(e)}\n\nSee START_HERE.md.\nDemo command: flutter run --dart-define=DEMO=true',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData portalTheme(bool dark) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: dark ? accent : const Color(0xff007f73),
        surface: dark ? const Color(0xff111f30) : Colors.white,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xff091320)
        : const Color(0xfff4f7fa),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff091320) : const Color(0xfff4f7fa),
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff192b3e) : const Color(0xfff0f4f8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: .12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: accent.withValues(alpha: .18),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .18),
    child: SizedBox.square(
      dimension: size,
      child: OverflowBox(
        minWidth: size * 1.6,
        maxWidth: size * 1.6,
        minHeight: size * 1.6,
        maxHeight: size * 1.6,
        child: Image.asset('assets/logo.png', fit: BoxFit.fill),
      ),
    ),
  );
}

class NextRole extends StatelessWidget {
  const NextRole({super.key, required this.store});
  final PortalStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NextRole',
      theme: portalTheme(store.dark),
      home: store.demo || store.uid.isNotEmpty
          ? Workspace(key: ValueKey(store.uid), store: store)
          : AuthScreen(store: store),
    ),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.store});
  final PortalStore store;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  PortalStore get s => widget.store;
  int page = 0;
  bool busy = false, filters = false;
  bool liveSource = true;
  String type = 'All',
      mode = 'All',
      field = 'All',
      sort = 'Newest',
      jobState = 'All',
      applicationStage = 'All',
      appSearch = '';
  final query = TextEditingController(), location = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    location.dispose();
    super.dispose();
  }

  void go(int i) {
    setState(() => page = i);
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> act(Future<void> Function() action, {String? success}) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await action();
      if (success != null) {
        message(success);
      }
    } catch (e) {
      message(friendly(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  List<Map<String, dynamic>> get visibleJobs {
    final data = s.role == 'candidate'
        ? filterJobs(
            s.jobs,
            search: query.text,
            type: type,
            mode: mode,
            field: field,
            location: location.text,
          )
        : s.jobs
              .where(
                (j) =>
                    '${j['title']} ${j['company']} ${j['skills']}'
                        .toLowerCase()
                        .contains(query.text.toLowerCase()) &&
                    (jobState == 'All' ||
                        (jobState == 'Closed'
                            ? j['open'] != true
                            : j['approval'] == jobState.toLowerCase())) &&
                    (type == 'All' || j['type'] == type) &&
                    (mode == 'All' || j['mode'] == mode) &&
                    (field == 'All' || j['field'] == field) &&
                    (j['location'] as String).toLowerCase().contains(
                      location.text.toLowerCase(),
                    ),
              )
              .toList();
    if (sort == 'Closing soon') {
      data.sort(
        (a, b) => (a['deadlineMs'] as int).compareTo(b['deadlineMs'] as int),
      );
    } else if (sort == 'Skill relevance') {
      data.sort(
        (a, b) => skillMatches(b, s.me!).compareTo(skillMatches(a, s.me!)),
      );
    } else {
      data.sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
    }
    return data;
  }

  Future<void> editJob([Map<String, dynamic>? job]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => JobDialog(store: s, job: job),
    );
  }

  Future<void> detail(Map<String, dynamic> j) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        maxChildSize: .96,
        minChildSize: .4,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 32),
          children: [
            CompanyMark(j['company'] as String, size: 60),
            const SizedBox(height: 20),
            PageHeading(j['title'] as String, j['company'] as String),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in ['location', 'mode', 'type'])
                  Pill(j[key] as String),
              ],
            ),
            const SizedBox(height: 20),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'COMPENSATION',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    j['salary'] as String,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Applications close ${dateLabel(j['deadline'] as String)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            sectionText('The opportunity', j['description'] as String),
            sectionText('What you bring', j['skills'] as String),
            if (s.role == 'candidate') ...[
              FilledButton.icon(
                onPressed:
                    !available(j) ||
                        s.applications.any((a) => a['jobId'] == j['id'])
                    ? null
                    : () {
                        Navigator.pop(sheet);
                        showDialog<void>(
                          context: context,
                          builder: (_) => ApplyDialog(store: s, job: j),
                        );
                      },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  s.applications.any((a) => a['jobId'] == j['id'])
                      ? 'Application already submitted'
                      : 'Apply with your profile',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.pop(sheet);
                        act(
                          () => s.bookmark(j['id'] as String),
                          success: 'Saved list updated.',
                        );
                      },
                icon: const Icon(Icons.bookmark_border),
                label: Text(
                  (s.me!['saved'] as List).contains(j['id'])
                      ? 'Remove from saved'
                      : 'Save for later',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  report(j);
                },
                child: const Text('Report listing'),
              ),
            ] else
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  editJob(j);
                },
                child: const Text('Edit vacancy'),
              ),
            TextButton.icon(
              onPressed: () => act(
                () => Clipboard.setData(
                  ClipboardData(
                    text:
                        '${j['title']} at ${j['company']}\n${j['location']} · ${j['type']} · ${j['mode']}\n${j['salary']}\nApply in NextRole before ${dateLabel(j['deadline'] as String)}.',
                  ),
                ),
                success: 'Role details copied.',
              ),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy role summary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionText(String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SelectableText(
          body.isEmpty ? 'Not provided' : body,
          style: const TextStyle(height: 1.65),
        ),
      ],
    ),
  );
  Future<void> report(Map<String, dynamic> j) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const TextPrompt(
        title: 'Report a listing',
        label: 'Reason for review',
        max: 1000,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    await act(
      () => s.report(j['id'] as String, result),
      success: 'Report sent to the administrator.',
    );
  }

  Widget jobCard(Map<String, dynamic> j) {
    final saved = (s.me!['saved'] as List).contains(j['id']);
    final applied = s.applications.any((a) => a['jobId'] == j['id']);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyMark(j['company'] as String),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      j['company'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      j['location'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (s.role == 'candidate')
                IconButton(
                  tooltip: saved ? 'Unsave role' : 'Save role',
                  onPressed: busy
                      ? null
                      : () => act(() => s.bookmark(j['id'] as String)),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? accent : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            j['title'] as String,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              Pill(j['type'] as String),
              Pill(j['mode'] as String, color: const Color(0xff7797d4)),
              if (applied) const Pill('Applied', color: Color(0xff9b8cff)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            j['salary'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Deadline ${dateLabel(j['deadline'] as String)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (s.role == 'candidate')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => detail(j),
                child: const Text('View opportunity'),
              ),
            )
          else ...[
            Pill(
              j['open'] == true ? j['approval'] as String : 'Closed',
              color: statusColor(j['approval'] as String),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : () => editJob(j),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final yes = await confirm(
                            j['open'] == true
                                ? 'Close this role?'
                                : 'Reopen this role?',
                            'Candidates can apply only while a role is open, approved and before its deadline.',
                          );
                          if (!mounted || !yes) {
                            return;
                          }
                          await act(
                            () => s.jobChange(j['id'] as String, {
                              'open': j['open'] != true,
                            }),
                          );
                        },
                  child: Text(j['open'] == true ? 'Close' : 'Reopen'),
                ),
                if (s.role == 'admin') ...[
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => act(
                            () => s.jobChange(j['id'] as String, {
                              'approval': 'approved',
                            }),
                            success: 'Listing approved.',
                          ),
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final yes = await confirm(
                              'Reject listing?',
                              'The listing will be closed and hidden from candidates.',
                            );
                            if (!mounted || !yes) {
                              return;
                            }
                            await act(
                              () => s.jobChange(j['id'] as String, {
                                'approval': 'rejected',
                                'open': false,
                              }),
                            );
                          },
                    child: const Text('Reject'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget jobsGrid(
    List<Map<String, dynamic>> jobs, {
    String empty = 'No roles here yet',
    String? description,
  }) => jobs.isEmpty
      ? EmptyState(
          empty,
          description ??
              (s.role == 'candidate'
                  ? 'Employers publish vacancies here after administrator approval. A new Firebase project starts empty.'
                  : 'Post a vacancy to start your hiring pipeline.'),
          action: s.role == 'candidate'
              ? TextButton(
                  onPressed: () => go(1),
                  child: const Text('Explore all roles'),
                )
              : FilledButton(
                  onPressed: () => editJob(),
                  child: const Text('Post your first role'),
                ),
        )
      : AdaptiveTiles(children: jobs.map(jobCard).toList());
  Widget stat(String title, String value, IconData icon) => Surface(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
  Widget home() {
    final m = s.me!;
    final ready = profileCompletion(m);
    final activeJobs = s.jobs.where(available).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Hello, ${firstName(m['name'] as String)}',
          s.role == 'candidate'
              ? 'Your next chapter starts with a thoughtful choice.'
              : 'Your hiring workspace, clearly organized.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [ink, Color(0xff0e555c)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Pill('NEXTROLE / MOVE FORWARD'),
              const SizedBox(height: 18),
              Text(
                s.role == 'candidate'
                    ? 'Find work that\nfits your ambition.'
                    : 'Great teams start\nwith the right people.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 29,
                  height: 1.2,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.role == 'candidate'
                    ? 'Discover roles. Build your profile. Follow every application.'
                    : 'Publish opportunities and make every hiring decision count.',
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => go(1),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  s.role == 'candidate'
                      ? 'Discover opportunities'
                      : 'Manage opportunities',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdaptiveTiles(
          minWidth: 135,
          gap: 12,
          children: [
            stat('Portal roles', '$activeJobs', Icons.work_outline),
            stat(
              'Applications',
              '${s.applications.length}',
              Icons.send_outlined,
            ),
            stat(
              'Shortlisted',
              '${s.applications.where((a) => a['status'] == 'Shortlisted').length}',
              Icons.stars_outlined,
            ),
            stat(
              s.role == 'admin' ? 'Pending companies' : 'Selected',
              s.role == 'admin'
                  ? '${s.people.where((p) => p['role'] == 'employer' && p['companyApproved'] != true).length}'
                  : '${s.applications.where((a) => a['status'] == 'Selected').length}',
              Icons.verified_outlined,
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (s.role == 'candidate') ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Profile readiness · $ready%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: ready / 100,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Share your education, skills and experience with every application. No CV upload needed.',
                ),
                TextButton(
                  onPressed: () => go(4),
                  child: const Text('Complete your profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (s.role == 'candidate' && !s.demo) ...[
          LiveJobsView(prefs: s.prefs, maxJobs: 4),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => go(1),
            child: const Text('Explore all live opportunities'),
          ),
          const SizedBox(height: 24),
        ],
        PageHeading(
          s.role == 'candidate' ? 'NextRole employers' : 'Hiring overview',
          s.demo
              ? 'Sample vacancies for exploring the full workflow.'
              : 'Live listings from your Firebase workspace.',
        ),
        jobsGrid(
          (s.role == 'candidate' ? filterJobs(s.jobs) : s.jobs)
              .take(4)
              .toList(),
        ),
      ],
    );
  }

  void resetFilters() {
    setState(() {
      query.clear();
      location.clear();
      type = mode = field = jobState = 'All';
      sort = 'Newest';
    });
  }

  Widget portalExplore() {
    final results = visibleJobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          s.role == 'candidate' ? 'Your next opportunity' : 'Manage vacancies',
          s.role == 'candidate'
              ? 'Discover jobs and internships that move you forward.'
              : 'Draft, publish and manage your opportunities.',
          action: s.role != 'candidate'
              ? FilledButton.icon(
                  onPressed: () => editJob(),
                  icon: const Icon(Icons.add),
                  label: const Text('Post a role'),
                )
              : null,
        ),
        TextField(
          controller: query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search title, company or skills',
            suffixIcon: query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      query.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in ['All', ...workModes])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option == 'All' ? 'All locations' : option),
                    selected: mode == option,
                    onSelected: (_) => setState(() => mode = option),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => filters = !filters),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(filters ? 'Hide filters' : 'More filters'),
            ),
            if (type != 'All' ||
                field != 'All' ||
                location.text.isNotEmpty ||
                query.text.isNotEmpty ||
                mode != 'All' ||
                jobState != 'All')
              TextButton(
                onPressed: resetFilters,
                child: const Text('Reset filters'),
              ),
          ],
        ),
        if (filters) ...[
          const SizedBox(height: 14),
          Surface(
            padding: 16,
            child: AdaptiveTiles(
              minWidth: 230,
              gap: 12,
              children: [
                TextField(
                  controller: location,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'City or location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                dropdown('Job type', type, [
                  'All',
                  ...jobTypes,
                ], (v) => setState(() => type = v)),
                dropdown('Career field', field, [
                  'All',
                  ...fields,
                ], (v) => setState(() => field = v)),
                if (s.role != 'candidate')
                  dropdown('Listing status', jobState, [
                    'All',
                    'Pending',
                    'Approved',
                    'Rejected',
                    'Closed',
                  ], (v) => setState(() => jobState = v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        AdaptiveTiles(
          minWidth: 230,
          gap: 12,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '${results.length} ${results.length == 1 ? 'opportunity' : 'opportunities'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            dropdown('Sort by', sort, [
              'Newest',
              'Closing soon',
              if (s.role == 'candidate') 'Skill relevance',
            ], (v) => setState(() => sort = v)),
          ],
        ),
        const SizedBox(height: 16),
        results.isEmpty
            ? EmptyState(
                'No matching opportunities',
                s.jobs.isEmpty
                    ? 'Your cloud workspace has no published jobs yet. An approved employer or administrator needs to post a role.'
                    : 'Try a broader search or reset your filters.',
                action: s.role == 'candidate'
                    ? TextButton(
                        onPressed: resetFilters,
                        child: const Text('Reset search'),
                      )
                    : FilledButton(
                        onPressed: () => editJob(),
                        child: const Text('Post a role'),
                      ),
              )
            : jobsGrid(results),
      ],
    );
  }

  Widget explore() {
    if (s.role != 'candidate') {
      return portalExplore();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Live jobs'),
              selected: liveSource,
              onSelected: (_) => setState(() => liveSource = true),
            ),
            ChoiceChip(
              label: const Text('NextRole employers'),
              selected: !liveSource,
              onSelected: (_) => setState(() => liveSource = false),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (liveSource)
          LiveJobsView(
            key: const ValueKey('public-feed'),
            prefs: s.prefs,
            enabled: !s.demo,
          )
        else
          portalExplore(),
      ],
    );
  }

  Future<void> applicationDetail(Map<String, dynamic> a) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .96,
        minChildSize: .4,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(22),
          children: [
            PageHeading(
              s.role == 'candidate'
                  ? a['jobTitle'] as String
                  : a['name'] as String,
              '${a['jobTitle']} · ${a['company']}',
            ),
            Pill(
              a['status'] as String,
              color: statusColor(a['status'] as String),
            ),
            const SizedBox(height: 20),
            sectionText(
              'Contact',
              '${a['name']}\n${a['email']}\n${a['headline']}',
            ),
            sectionText('Skills', a['skills'] as String),
            sectionText('Education', a['education'] as String),
            sectionText('Experience', a['experience'] as String),
            sectionText('Cover note', a['cover'] as String),
            const Text(
              'This profile snapshot reflects the details submitted when the candidate applied.',
            ),
            const SizedBox(height: 20),
            if (s.role != 'candidate' && a['status'] != 'Withdrawn') ...[
              const Text(
                'Move candidate to',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stage in stages.where((v) => v != 'Withdrawn'))
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        act(
                          () => s.status(a['id'] as String, stage),
                          success: 'Application moved to $stage.',
                        );
                      },
                      child: Text(stage),
                    ),
                ],
              ),
            ],
            if (s.role == 'candidate' &&
                [
                  'Applied',
                  'Under Review',
                  'Shortlisted',
                ].contains(a['status']))
              OutlinedButton(
                onPressed: () async {
                  final yes = await confirm(
                    'Withdraw application?',
                    'Your application will be marked as withdrawn. You cannot submit a second application for this role.',
                  );
                  if (!ctx.mounted || !yes) {
                    return;
                  }
                  Navigator.pop(ctx);
                  await act(
                    () => s.withdraw(a['id'] as String),
                    success: 'Application withdrawn.',
                  );
                },
                child: const Text('Withdraw application'),
              ),
          ],
        ),
      ),
    );
  }

  Widget applicationCard(Map<String, dynamic> a) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyMark(
              s.role == 'candidate'
                  ? a['company'] as String
                  : a['name'] as String,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.role == 'candidate'
                        ? a['jobTitle'] as String
                        : a['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.role == 'candidate'
                        ? a['company'] as String
                        : a['jobTitle'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Pill(a['status'] as String, color: statusColor(a['status'] as String)),
        const SizedBox(height: 12),
        Text(
          'Submitted ${dateLabel(a['createdAt'] as String)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        if (s.role == 'candidate') ...[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final stage in [
                'Applied',
                'Under Review',
                'Shortlisted',
                'Selected',
              ])
                Icon(
                  stages.indexOf(a['status'] as String) >=
                              stages.indexOf(stage) &&
                          !['Rejected', 'Withdrawn'].contains(a['status'])
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 18,
                  color: statusColor(a['status'] as String),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => applicationDetail(a),
            child: Text(
              s.role == 'candidate' ? 'View application' : 'Review candidate',
            ),
          ),
        ),
      ],
    ),
  );
  Widget applicationPage() {
    final data =
        s.applications
            .where(
              (a) =>
                  (applicationStage == 'All' ||
                      a['status'] == applicationStage) &&
                  '${a['jobTitle']} ${a['company']} ${a['name']}'
                      .toLowerCase()
                      .contains(appSearch.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          s.role == 'candidate' ? 'Your applications' : 'Candidate pipeline',
          s.role == 'candidate'
              ? 'Follow your progress, review your submission or withdraw.'
              : 'Review profile snapshots and keep candidates informed.',
        ),
        TextField(
          onChanged: (v) => setState(() => appSearch = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search applications',
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final stage in ['All', ...stages])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$stage (${s.applications.where((a) => stage == 'All' || a['status'] == stage).length})',
                    ),
                    selected: applicationStage == stage,
                    onSelected: (_) => setState(() => applicationStage = stage),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (data.isEmpty)
          EmptyState(
            'No applications in this view',
            s.role == 'candidate'
                ? 'Explore a role and apply with your profile to start your journey.'
                : 'Applications arrive here when candidates apply to your published roles.',
            icon: Icons.inbox_outlined,
          )
        else
          AdaptiveTiles(children: data.map(applicationCard).toList()),
      ],
    );
  }

  Widget saved() {
    final ids = s.me!['saved'] as List;
    final data = s.jobs.where((j) => ids.contains(j['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Saved for later',
          'Keep promising opportunities close.',
        ),
        if (ids.length > data.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${ids.length - data.length} saved roles are no longer visible because they were closed or removed.',
            ),
          ),
        jobsGrid(
          data,
          empty: 'Build your shortlist',
          description: 'Tap the bookmark on any role to save it here.',
        ),
      ],
    );
  }

  Widget insights() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Hiring insights',
        'Counts from your actual vacancies and applications.',
      ),
      AdaptiveTiles(
        minWidth: 170,
        children: [
          stat(
            'Published roles',
            '${s.jobs.where((j) => j['approval'] == 'approved' && available(j)).length}',
            Icons.public,
          ),
          stat(
            'Awaiting approval',
            '${s.jobs.where((j) => j['approval'] == 'pending').length}',
            Icons.hourglass_empty,
          ),
          stat(
            'Total applicants',
            '${s.applications.length}',
            Icons.people_outline,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application pipeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            for (final stage in stages) ...[
              Row(
                children: [
                  Expanded(child: Text(stage)),
                  Text(
                    '${s.applications.where((a) => a['status'] == stage).length}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: s.applications.isEmpty
                    ? 0
                    : s.applications.where((a) => a['status'] == stage).length /
                          s.applications.length,
                color: statusColor(stage),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (s.jobs.isNotEmpty)
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Applications by role',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              for (final j in s.jobs)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(j['title'] as String)),
                      const SizedBox(width: 12),
                      Pill(
                        '${s.applications.where((a) => a['jobId'] == j['id']).length}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ],
  );
  Widget adminPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Workspace control',
        'Approve companies, manage access and investigate reports.',
      ),
      for (final p in s.people)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(p['email'] as String),
                const SizedBox(height: 10),
                Pill(p['role'] as String),
                if (p['role'] == 'employer') ...[
                  const SizedBox(height: 12),
                  sectionText(
                    'Company',
                    '${p['company']}\n${p['website']}\n${p['bio']}',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Company approval'),
                    subtitle: const Text(
                      'Approved companies can submit vacancies.',
                    ),
                    value: p['companyApproved'] == true,
                    onChanged: busy
                        ? null
                        : (v) => act(
                            () => s.userChange(p['id'] as String, {
                              'companyApproved': v,
                            }),
                          ),
                  ),
                ],
                if (p['id'] != s.uid)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account access'),
                    value: p['active'] == true,
                    onChanged: busy
                        ? null
                        : (v) async {
                            if (!v) {
                              final yes = await confirm(
                                'Pause account?',
                                'This account will lose access to jobs and applications until reactivated.',
                              );
                              if (!mounted || !yes) {
                                return;
                              }
                            }
                            await act(
                              () => s.userChange(p['id'] as String, {
                                'active': v,
                              }),
                            );
                          },
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
      const PageHeading(
        'Reports',
        'Review the related listing before resolving a report.',
      ),
      if (s.reports.where((r) => r['resolved'] != true).isEmpty)
        const EmptyState(
          'No open reports',
          'Reports submitted by candidates will appear here.',
          icon: Icons.verified_user_outlined,
        ),
      for (final r in s.reports.where((r) => r['resolved'] != true))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['reason'] as String),
                const SizedBox(height: 12),
                Text('Role ID: ${r['jobId']}'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        final matches = s.jobs.where(
                          (j) => j['id'] == r['jobId'],
                        );
                        if (matches.isEmpty) {
                          message('This listing is no longer available.');
                        } else {
                          detail(matches.first);
                        }
                      },
                      child: const Text('Inspect listing'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => act(
                              () => s.resolve(r['id'] as String),
                              success: 'Report resolved.',
                            ),
                      child: const Text('Resolve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (s.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s.me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complete account')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (s.error != null) Text(s.error!),
              ProfileRecovery(store: s),
              TextButton(
                onPressed: () => act(s.signOut),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }
    if (s.me!['active'] != true) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                'Account access paused',
                'Contact your administrator to restore access.',
                icon: Icons.lock_outline,
                action: TextButton(
                  onPressed: () => act(s.signOut),
                  child: const Text('Sign out'),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final labels = [
      'Home',
      s.role == 'candidate' ? 'Explore' : 'Vacancies',
      'Applications',
      s.role == 'admin'
          ? 'Moderation'
          : s.role == 'employer'
          ? 'Insights'
          : 'Saved',
      'Profile',
    ];
    final icons = [
      Icons.space_dashboard_outlined,
      Icons.search_rounded,
      Icons.work_outline,
      s.role == 'admin'
          ? Icons.shield_outlined
          : s.role == 'employer'
          ? Icons.insights
          : Icons.bookmark_border,
      Icons.person_outline,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Brand(size: 34),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'NextRole',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (s.demo)
                PopupMenuButton<String>(
                  tooltip: 'Demo role',
                  onSelected: (v) => act(() => s.switchRole(v)),
                  itemBuilder: (_) => ['candidate', 'employer', 'admin']
                      .map(
                        (r) => PopupMenuItem(value: r, child: Text('Demo $r')),
                      )
                      .toList(),
                  icon: const Icon(Icons.swap_horiz),
                ),
              IconButton(
                tooltip: 'Change appearance',
                onPressed: () => act(s.theme),
                icon: Icon(
                  s.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: go,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (wide)
                  NavigationRail(
                    extended: true,
                    minExtendedWidth: 270,
                    selectedIndex: page,
                    onDestinationSelected: go,
                    destinations: List.generate(
                      5,
                      (i) => NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (s.demo)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          color: accent.withValues(alpha: .1),
                          child: Text(
                            'LOCAL DEMO · ${s.role} · Sample data',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (busy) const LinearProgressIndicator(minHeight: 2),
                      if (s.error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Surface(
                            padding: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(s.error!),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => act(
                                          () => s.session(
                                            FirebaseAuth.instance.currentUser,
                                          ),
                                        ),
                                  child: const Text('Reconnect'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: ListView(
                              key: ValueKey('$page:${s.uid}'),
                              padding: EdgeInsets.fromLTRB(
                                wide ? 28 : 18,
                                18,
                                wide ? 28 : 18,
                                28,
                              ),
                              children: [
                                switch (page) {
                                  0 => home(),
                                  1 => explore(),
                                  2 => applicationPage(),
                                  3 =>
                                    s.role == 'admin'
                                        ? adminPage()
                                        : s.role == 'employer'
                                        ? insights()
                                        : saved(),
                                  _ => ProfileScreen(
                                    key: ValueKey(s.uid),
                                    store: s,
                                  ),
                                },
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget select(
  String label,
  String value,
  List<String> options,
  void Function(String) changed,
) => dropdown(label, value, options, changed);
