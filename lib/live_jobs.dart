import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui.dart';
import 'models.dart' show dateLabel;

Uri? sourceUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      ![
        'arbeitnow.com',
        'www.arbeitnow.com',
        'arbeitnow.co.uk',
        'www.arbeitnow.co.uk',
      ].contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  return uri;
}

String plainDescription(String source) {
  final document = html.parse(source);
  for (final element in document.querySelectorAll('script,style,iframe')) {
    element.remove();
  }
  for (final element in document.querySelectorAll('p,div,li,h1,h2,h3,h4,br')) {
    element.append(dom.Text('\n'));
  }
  return (document.body?.text ?? '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
      .trim();
}

class PublicJob {
  PublicJob({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.location,
    required this.remote,
    required this.url,
    required this.tags,
    required this.types,
    required this.created,
  });
  final String id, title, company, description, location;
  final bool remote;
  final Uri url;
  final List<String> tags, types;
  final DateTime? created;
  static PublicJob? parse(Map<String, dynamic> raw) {
    String str(String key) =>
        raw[key] is String ? (raw[key] as String).trim() : '';
    final link = sourceUrl(str('url'));
    final id = str('slug'), title = str('title'), company = str('company_name');
    if (link == null || id.isEmpty || title.isEmpty || company.isEmpty) {
      return null;
    }
    List<String> values(String key) => raw[key] is List
        ? (raw[key] as List)
              .whereType<String>()
              .where((v) => v.trim().isNotEmpty)
              .toList()
        : [];
    DateTime? created;
    final stamp = raw['created_at'];
    if (stamp is num) {
      try {
        created = DateTime.fromMillisecondsSinceEpoch(
          (stamp * 1000).toInt(),
          isUtc: true,
        );
      } catch (_) {
        created = null;
      }
    }
    return PublicJob(
      id: id,
      title: title,
      company: company,
      description: plainDescription(str('description')),
      location: str('location'),
      remote: raw['remote'] == true,
      url: link,
      tags: values('tags'),
      types: values('job_types'),
      created: created,
    );
  }
}

class PublicJobsFeed extends ChangeNotifier {
  PublicJobsFeed({
    required this.prefs,
    http.Client? client,
    DateTime Function()? clock,
  }) : client = client ?? http.Client(),
       clock = clock ?? DateTime.now;
  final SharedPreferences prefs;
  final http.Client client;
  final DateTime Function() clock;
  List<PublicJob> jobs = [];
  Set<String> saved = {};
  bool loading = false, closed = false;
  String? error;
  DateTime? updated, lastAttempt;
  static const endpoint = 'https://www.arbeitnow.com/api/job-board-api';
  static const cacheKey = 'nextrole.publicJobs.arbeitnow.v1';
  void emit() {
    if (!closed) {
      notifyListeners();
    }
  }

  List<PublicJob> decodeJobs(Object? value) {
    if (value is! List) {
      throw const FormatException('Unexpected jobs payload');
    }
    final unique = <String, PublicJob>{};
    for (final row in value) {
      if (row is Map<String, dynamic>) {
        try {
          final job = PublicJob.parse(row);
          if (job != null) {
            unique[job.id] = job;
          }
        } catch (_) {
          continue;
        }
      }
    }
    if (value.isNotEmpty && unique.isEmpty) {
      throw const FormatException('No valid job records');
    }
    return unique.values.toList()..sort(
      (a, b) =>
          (b.created ?? DateTime(1970)).compareTo(a.created ?? DateTime(1970)),
    );
  }

  Future<void> initialize() async {
    saved = (prefs.getStringList('nextrole.publicJobs.saved') ?? []).toSet();
    try {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        jobs = decodeJobs(data['data']);
        updated = DateTime.tryParse(data['updated'] as String);
      }
    } catch (_) {
      jobs = [];
      updated = null;
    }
    lastAttempt = DateTime.tryParse(
      prefs.getString('nextrole.publicJobs.lastAttempt') ?? '',
    );
    emit();
    await refresh();
  }

  Future<void> refresh({bool manual = false}) async {
    if (closed || loading) {
      return;
    }
    final now = clock();
    if (!manual &&
        updated != null &&
        now.difference(updated!) < const Duration(hours: 6)) {
      return;
    }
    if (lastAttempt != null &&
        now.difference(lastAttempt!) < const Duration(minutes: 5)) {
      error =
          'Please wait five minutes between feed requests. Showing the latest available data.';
      emit();
      return;
    }
    lastAttempt = now;
    loading = true;
    error = null;
    emit();
    try {
      try {
        await prefs.setString(
          'nextrole.publicJobs.lastAttempt',
          now.toIso8601String(),
        );
      } catch (_) {
        /* Network fetch can continue without a local cache. */
      }
      if (closed) {
        return;
      }
      final response = await client
          .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 18));
      if (closed) {
        return;
      }
      if (response.statusCode != 200) {
        throw StateError(
          response.statusCode == 429
              ? 'The source is rate limiting requests. Please try later.'
              : 'Job source returned HTTP ${response.statusCode}. Please try later.',
        );
      }
      if (response.bodyBytes.length > 5 * 1024 * 1024) {
        throw StateError(
          'The source response is too large. Please retry later.',
        );
      }
      final payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final fresh = decodeJobs(payload['data']);
      jobs = fresh;
      updated = clock();
      try {
        await prefs.setString(
          cacheKey,
          jsonEncode({
            'updated': updated!.toIso8601String(),
            'data': payload['data'],
          }),
        );
      } catch (_) {
        /* Live results remain available if device cache is full. */
      }
    } on TimeoutException {
      error = 'The jobs source took too long. Check your connection and retry.';
    } on StateError catch (e) {
      error = e.message.toString();
    } catch (_) {
      error =
          'Live jobs could not be refreshed. Check your internet connection and try again.';
    } finally {
      loading = false;
      emit();
    }
  }

  Future<void> toggleSaved(String id) async {
    if (!saved.contains(id) && saved.length >= 300) {
      throw StateError('You can save up to 300 external roles.');
    }
    final previous = Set<String>.of(saved);
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    try {
      if (!await prefs.setStringList(
        'nextrole.publicJobs.saved',
        saved.toList(),
      )) {
        throw StateError('Could not save on this device.');
      }
    } catch (_) {
      saved = previous;
      rethrow;
    }
    emit();
  }

  @override
  void dispose() {
    closed = true;
    client.close();
    super.dispose();
  }
}

class LiveJobsView extends StatefulWidget {
  const LiveJobsView({
    super.key,
    required this.prefs,
    this.enabled = true,
    this.maxJobs,
  });
  final SharedPreferences prefs;
  final bool enabled;
  final int? maxJobs;
  @override
  State<LiveJobsView> createState() => _LiveJobsViewState();
}

class _LiveJobsViewState extends State<LiveJobsView> {
  late final PublicJobsFeed feed;
  final query = TextEditingController(), location = TextEditingController();
  String mode = 'All';
  bool savedOnly = false;
  @override
  void initState() {
    super.initState();
    feed = PublicJobsFeed(prefs: widget.prefs);
    if (widget.enabled) {
      unawaited(feed.initialize());
    }
  }

  @override
  void dispose() {
    query.dispose();
    location.dispose();
    feed.dispose();
    super.dispose();
  }

  void notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> open(PublicJob job) async {
    try {
      final success = await launchUrl(
        job.url,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        notice('Could not open your browser. Try again.');
      }
    } catch (_) {
      notice('The original job page could not be opened.');
    }
  }

  Future<void> save(PublicJob job) async {
    try {
      await feed.toggleSaved(job.id);
    } catch (e) {
      notice(
        e is StateError ? e.message.toString() : 'Could not save this role.',
      );
    }
  }

  Future<void> detail(PublicJob job) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        maxChildSize: .96,
        minChildSize: .4,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(22),
          children: [
            PageHeading(job.title, job.company),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Pill('Source: Arbeitnow'),
                Pill(
                  job.remote ? 'Remote' : 'Location-based',
                  color: const Color(0xff7797d4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              job.location.isEmpty ? 'Location not specified' : job.location,
            ),
            const SizedBox(height: 12),
            const Text(
              'Check the source for salary, deadline, language and location eligibility. Remote does not necessarily mean worldwide.',
            ),
            const SizedBox(height: 22),
            SelectableText(
              job.description.isEmpty
                  ? 'Read the full role on the original job page.'
                  : job.description,
              style: const TextStyle(height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => open(job),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apply on Arbeitnow'),
            ),
            const SizedBox(height: 12),
            const Text(
              'You will leave NextRole. External applications are handled by the original listing and are not tracked in My Applications.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget jobCard(PublicJob job) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyMark(job.company),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                job.company,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Save external job on device',
              onPressed: () => save(job),
              icon: Icon(
                feed.saved.contains(job.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          job.title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(job.location.isEmpty ? 'Location not specified' : job.location),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            const Pill('Arbeitnow'),
            if (job.remote) const Pill('Remote'),
            for (final type in job.types.take(2))
              Pill(type, color: const Color(0xff7797d4)),
          ],
        ),
        const SizedBox(height: 12),
        if (job.created != null)
          Text(
            'Posted ${dateLabel(job.created!.toIso8601String())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => detail(job),
            child: const Text('View real opportunity'),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const EmptyState(
        'Live feed is available in normal mode',
        'Demo uses sample jobs so tests and local previews work without internet. Run without --dart-define=DEMO=true to load real listings.',
        icon: Icons.public,
      );
    }
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final results = feed.jobs
            .where(
              (j) =>
                  (!savedOnly || feed.saved.contains(j.id)) &&
                  (mode != 'Remote' || j.remote) &&
                  '${j.title} ${j.company} ${j.description} ${j.tags.join(' ')}'
                      .toLowerCase()
                      .contains(query.text.trim().toLowerCase()) &&
                  j.location.toLowerCase().contains(
                    location.text.trim().toLowerCase(),
                  ),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeading(
              'Live opportunities',
              'Real listings from Arbeitnow, mainly Europe. Check each role’s location and eligibility.',
            ),
            Surface(
              padding: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Pill('Powered by Arbeitnow'),
                  const SizedBox(height: 10),
                  Text(
                    feed.updated == null
                        ? 'Loading the latest jobs…'
                        : 'Last synced ${dateLabel(feed.updated!.toIso8601String())} · Cached between requests',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: feed.loading
                            ? null
                            : () => feed.refresh(manual: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh feed'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await launchUrl(
                              Uri.parse('https://www.arbeitnow.com'),
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            notice('Could not open the source website.');
                          }
                        },
                        child: const Text('Visit source'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (feed.loading) const LinearProgressIndicator(),
            if (feed.error != null) ...[
              Text(
                feed.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search live jobs or skills',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: location,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: 'City or location',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All jobs'),
                  selected: mode == 'All',
                  onSelected: (_) => setState(() => mode = 'All'),
                ),
                ChoiceChip(
                  label: const Text('Remote'),
                  selected: mode == 'Remote',
                  onSelected: (_) => setState(() => mode = 'Remote'),
                ),
                FilterChip(
                  label: const Text('Saved on device'),
                  selected: savedOnly,
                  onSelected: (v) => setState(() => savedOnly = v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '${results.length} real opportunities',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            if (results.isEmpty && !feed.loading)
              EmptyState(
                feed.jobs.isEmpty
                    ? 'Live feed unavailable'
                    : 'No matching live roles',
                feed.jobs.isEmpty
                    ? 'Refresh after checking your connection. No fake jobs are substituted.'
                    : 'Broaden your search or remove the filters.',
              )
            else
              AdaptiveTiles(
                children:
                    (widget.maxJobs == null
                            ? results
                            : results.take(widget.maxJobs!))
                        .map(jobCard)
                        .toList(),
              ),
          ],
        );
      },
    );
  }
}
