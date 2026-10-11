import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'store.dart';
import 'main.dart' show Brand, select;
import 'ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});
  final PortalStore store;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hide = true;
  String role = 'candidate';
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (busy) {
      return;
    }
    if (reset) {
      if (!email.text.contains('@')) {
        setState(() => error = 'Enter your email address first.');
        return;
      }
    } else if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email.text.trim(),
        );
        if (mounted) {
          setState(
            () =>
                error = 'If an account exists, you will receive a reset email.',
          );
        }
      } else if (register) {
        await widget.store.register(
          name.text.trim(),
          email.text.trim(),
          password.text,
          role,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Wrap(
                spacing: 40,
                runSpacing: 28,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: c.maxWidth >= 900
                        ? 440
                        : (c.maxWidth - 44).clamp(0, 480).toDouble(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Brand(size: 64),
                        const SizedBox(height: 24),
                        const Text(
                          'A better way\nto move forward.',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Meaningful opportunities. Thoughtful hiring. One connected workspace.',
                          style: TextStyle(height: 1.6, fontSize: 16),
                        ),
                        if (c.maxWidth >= 900) ...[
                          const SizedBox(height: 32),
                          for (final label in [
                            'Discover jobs and internships',
                            'Track every application',
                            'Build a team that fits',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(label)),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: c.maxWidth >= 900
                        ? 440
                        : (c.maxWidth - 44).clamp(0, 480).toDouble(),
                    child: Surface(
                      padding: 24,
                      child: Form(
                        key: form,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                register
                                    ? 'Create your account'
                                    : 'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                register
                                    ? 'Choose your role and start your next chapter.'
                                    : 'Sign in to your NextRole workspace.',
                              ),
                              const SizedBox(height: 24),
                              if (register) ...[
                                input(name, 'Full name', max: 80),
                                const SizedBox(height: 14),
                                select('Account type', role, [
                                  'candidate',
                                  'employer',
                                ], (v) => setState(() => role = v)),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (v) =>
                                    RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(v ?? '')
                                    ? null
                                    : 'Enter a valid email address.',
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: password,
                                obscureText: hide,
                                autofillHints: [
                                  register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: 'Show or hide password',
                                    onPressed: () =>
                                        setState(() => hide = !hide),
                                    icon: Icon(
                                      hide
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v ?? '').length < 8
                                    ? 'Use at least 8 characters.'
                                    : null,
                              ),
                              if (!register)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => submit(reset: true),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (error != null) ...[
                                Text(
                                  error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              FilledButton(
                                onPressed: busy ? null : () => submit(),
                                child: Text(
                                  busy
                                      ? 'Please wait…'
                                      : register
                                      ? 'Create account'
                                      : 'Sign in',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        register = !register;
                                        error = null;
                                      }),
                                child: Text(
                                  register
                                      ? 'Already registered? Sign in'
                                      : 'New here? Create an account',
                                ),
                              ),
                              if (register && role == 'employer')
                                const Text(
                                  'Complete your company profile after signup. Administrator approval is required before posting vacancies.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, height: 1.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget input(
  TextEditingController controller,
  String label, {
  int max = 120,
  int lines = 1,
  bool required = true,
}) => TextFormField(
  controller: controller,
  maxLength: max,
  maxLines: lines,
  decoration: InputDecoration(labelText: label, counterText: ''),
  validator: (v) => (v ?? '').length > max
      ? 'Keep $label within $max characters.'
      : required && (v ?? '').trim().length < 2
      ? 'Enter $label.'
      : null,
);

class ProfileRecovery extends StatefulWidget {
  const ProfileRecovery({super.key, required this.store});
  final PortalStore store;
  @override
  State<ProfileRecovery> createState() => _ProfileRecoveryState();
}

class _ProfileRecoveryState extends State<ProfileRecovery> {
  final name = TextEditingController();
  String role = 'candidate';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      input(name, 'Full name', max: 80),
      select('Role', role, [
        'candidate',
        'employer',
      ], (v) => setState(() => role = v)),
      if (error != null) Text(error!),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (name.text.trim().length < 2) {
                  return;
                }
                setState(() => busy = true);
                try {
                  await widget.store.repairProfile(name.text.trim(), role);
                } catch (e) {
                  if (mounted) {
                    setState(() => error = friendly(e));
                  }
                } finally {
                  if (mounted) {
                    setState(() => busy = false);
                  }
                }
              },
        child: const Text('Complete profile'),
      ),
    ],
  );
}

class TextPrompt extends StatefulWidget {
  const TextPrompt({
    super.key,
    required this.title,
    required this.label,
    required this.max,
  });
  final String title, label;
  final int max;
  @override
  State<TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<TextPrompt> {
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: form,
      child: input(text, widget.label, max: widget.max, lines: 4),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, text.text.trim());
          }
        },
        child: const Text('Submit'),
      ),
    ],
  );
}

class JobDialog extends StatefulWidget {
  const JobDialog({super.key, required this.store, this.job});
  final PortalStore store;
  final Map<String, dynamic>? job;
  @override
  State<JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends State<JobDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      skills = TextEditingController(),
      location = TextEditingController(),
      salary = TextEditingController();
  late String id, created;
  String type = 'Full-time', mode = 'Remote', field = 'Engineering';
  DateTime deadline = DateTime.now().add(const Duration(days: 30));
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final j = widget.job;
    id = j?['id'] as String? ?? const Uuid().v4();
    created = j?['createdAt'] as String? ?? DateTime.now().toIso8601String();
    if (j != null) {
      title.text = j['title'] as String;
      description.text = j['description'] as String;
      skills.text = j['skills'] as String;
      location.text = j['location'] as String;
      salary.text = j['salary'] as String;
      type = j['type'] as String;
      mode = j['mode'] as String;
      field = j['field'] as String;
      deadline = DateTime.parse(j['deadline'] as String);
    }
  }

  @override
  void dispose() {
    for (final c in [title, description, skills, location, salary]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) {
      return;
    }
    final s = widget.store;
    if (s.role == 'employer' &&
        (s.me!['companyApproved'] != true ||
            (s.me!['company'] as String).trim().length < 2)) {
      setState(
        () => error =
            'Complete your company profile and ask the administrator to approve it before posting.',
      );
      return;
    }
    if (!deadline.isAfter(DateTime.now())) {
      setState(() => error = 'Choose a future deadline.');
      return;
    }
    setState(() => busy = true);
    try {
      await s.saveJob({
        'id': id,
        'ownerId': widget.job?['ownerId'] ?? s.uid,
        'company':
            widget.job?['company'] ??
            ((s.me!['company'] as String).isEmpty
                ? s.me!['name']
                : s.me!['company']),
        'title': title.text.trim(),
        'description': description.text.trim(),
        'skills': skills.text.trim(),
        'location': location.text.trim(),
        'salary': salary.text.trim().isEmpty
            ? 'Not disclosed'
            : salary.text.trim(),
        'type': type,
        'mode': mode,
        'field': field,
        'deadline': deadline.toIso8601String(),
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'createdAt': created,
        'approval': s.role == 'admin' ? 'approved' : 'pending',
        'open': widget.job?['open'] ?? true,
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.job == null ? 'Post an opportunity' : 'Edit vacancy'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              input(title, 'Job title'),
              const SizedBox(height: 12),
              input(description, 'Description', max: 6000, lines: 5),
              const SizedBox(height: 12),
              input(skills, 'Required skills', max: 1000, lines: 2),
              const SizedBox(height: 12),
              input(location, 'Location'),
              const SizedBox(height: 12),
              input(salary, 'Salary (optional)', required: false),
              const SizedBox(height: 12),
              select(
                'Job type',
                type,
                jobTypes,
                (v) => setState(() => type = v),
              ),
              const SizedBox(height: 12),
              select(
                'Work mode',
                mode,
                workModes,
                (v) => setState(() => mode = v),
              ),
              const SizedBox(height: 12),
              select('Field', field, fields, (v) => setState(() => field = v)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final first = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: deadline.isBefore(first)
                              ? first
                              : deadline,
                          firstDate: DateTime(
                            first.year,
                            first.month,
                            first.day,
                          ),
                          lastDate: first.add(const Duration(days: 730)),
                        );
                        if (d != null && mounted) {
                          setState(
                            () => deadline = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              23,
                              59,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.event),
                label: Text(
                  'Deadline ${dateLabel(deadline.toIso8601String())}',
                ),
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Saving…' : 'Save vacancy'),
      ),
    ],
  );
}

class ApplyDialog extends StatefulWidget {
  const ApplyDialog({super.key, required this.store, required this.job});
  final PortalStore store;
  final Map<String, dynamic> job;
  @override
  State<ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<ApplyDialog> {
  final cover = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Make your introduction'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.job['title']} · ${widget.job['company']}'),
            const SizedBox(height: 16),
            const Text(
              'Apply with your profile. Your name, email, education, skills and experience will be shared with the employer. Complete your profile before applying. No CV file is required.',
            ),
            const SizedBox(height: 16),
            input(
              cover,
              'Cover note (optional)',
              required: false,
              max: 3000,
              lines: 5,
            ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (cover.text.length > 3000) {
                  setState(
                    () =>
                        error = 'Keep your cover note within 3000 characters.',
                  );
                  return;
                }
                setState(() => busy = true);
                try {
                  await widget.store.apply(widget.job, cover.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => error = friendly(e));
                  }
                } finally {
                  if (mounted) {
                    setState(() => busy = false);
                  }
                }
              },
        child: Text(busy ? 'Submitting…' : 'Submit application'),
      ),
    ],
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store});
  final PortalStore store;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'name',
      'headline',
      'phone',
      'location',
      'bio',
      'skills',
      'education',
      'experience',
      'company',
      'website',
    ]) {
      controllers[key] = TextEditingController(
        text: widget.store.me![key] as String,
      );
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> action(Future<void> Function() fn, String message) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await fn();
      if (mounted) {
        setState(() => notice = message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => notice = friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> photo() async {
    await action(() async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 65,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 100000) {
        throw StateError(
          'Choose a smaller photo (under 100 KB after compression).',
        );
      }
      await widget.store.profile({'photo': base64Encode(bytes)});
    }, 'Profile photo updated.');
  }

  void save() {
    if (!form.currentState!.validate()) {
      return;
    }
    final s = widget.store;
    final m = s.me!;
    final values = <String, dynamic>{
      for (final e in controllers.entries) e.key: e.value.text.trim(),
    };
    if (s.role == 'employer' &&
        (values['company'] != m['company'] ||
            values['website'] != m['website'])) {
      values['companyApproved'] = false;
    }
    action(
      () => s.profile(values),
      'Profile saved. New applications will use these details.',
    );
  }

  Widget field(
    String key,
    String label, {
    int max = 200,
    int lines = 1,
    bool required = false,
  }) => input(
    controllers[key]!,
    label,
    max: max,
    lines: lines,
    required: required,
  );
  Widget section(String title, String subtitle, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final m = s.me!;
    ImageProvider? image;
    try {
      if ((m['photo'] as String).isNotEmpty) {
        image = MemoryImage(base64Decode(m['photo'] as String));
      }
    } catch (_) {
      image = null;
    }
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            s.role == 'employer'
                ? 'Your company & account'
                : 'Your professional profile',
            'Keep your details accurate and ready to share.',
          ),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: accent.withValues(alpha: .18),
                      backgroundImage: image,
                      child: image == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 34,
                              color: accent,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name'] as String,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(m['headline'] as String),
                          const SizedBox(height: 6),
                          Text(
                            m['email'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(s.role),
                    if (s.role == 'employer')
                      Pill(
                        m['companyApproved'] == true
                            ? 'Company approved'
                            : 'Approval pending',
                        color: m['companyApproved'] == true
                            ? accent
                            : const Color(0xffd99630),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : photo,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Change photo'),
                    ),
                    if ((m['photo'] as String).isNotEmpty)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                () => s.profile({'photo': ''}),
                                'Photo removed.',
                              ),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (s.role == 'candidate')
            section(
              'Profile readiness',
              'Complete these fields to introduce yourself to employers.',
              [
                LinearProgressIndicator(
                  value: profileCompletion(m) / 100,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  '${profileCompletion(m)}% complete · name, headline, location, skills, education and experience',
                ),
              ],
            ),
          section(
            'Personal details',
            'Your email is managed through Firebase Authentication.',
            [
              AdaptiveTiles(
                minWidth: 250,
                children: [
                  field('name', 'Full name', max: 80, required: true),
                  field('headline', 'Professional headline'),
                  field('phone', 'Phone number', max: 40),
                  field('location', 'Location'),
                ],
              ),
              const SizedBox(height: 16),
              field('bio', 'About you', max: 2000, lines: 4),
            ],
          ),
          if (s.role == 'candidate')
            section(
              'Career background',
              'These details are included as a snapshot with each application.',
              [
                field(
                  'skills',
                  'Skills (separate with commas)',
                  max: 2000,
                  lines: 3,
                ),
                const SizedBox(height: 16),
                field('education', 'Education', max: 2000, lines: 4),
                const SizedBox(height: 16),
                field(
                  'experience',
                  'Experience & projects',
                  max: 2000,
                  lines: 4,
                ),
              ],
            ),
          if (s.role == 'employer')
            section(
              'Company identity',
              'Changes to company name or website require approval again.',
              [
                field('company', 'Company name'),
                const SizedBox(height: 16),
                field('website', 'Company website'),
                const SizedBox(height: 14),
                const Text(
                  'An administrator reviews your company before you can publish vacancies. Provide clear company details in your bio.',
                ),
              ],
            ),
          if (notice != null) ...[
            Surface(padding: 14, child: Text(notice!)),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving…' : 'Save profile'),
          ),
          const SizedBox(height: 24),
          section(
            'Preferences & security',
            'Control your appearance and account access.',
            [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark appearance'),
                subtitle: const Text('Saved on this device'),
                value: s.dark,
                onChanged: busy
                    ? null
                    : (_) => action(s.theme, 'Appearance updated.'),
              ),
              if (!s.demo) ...[
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          await FirebaseAuth.instance.currentUser!
                              .sendEmailVerification();
                        }, 'Verification email sent.'),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Send verification email'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: m['email'] as String,
                          );
                        }, 'Password reset email sent.'),
                  icon: const Icon(Icons.password),
                  label: const Text('Reset password'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => action(s.signOut, 'Signed out.'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ] else
                const Text(
                  'Local demo account. Use the top toolbar to switch between candidate, employer and administrator.',
                ),
            ],
          ),
          const Center(
            child: Text('NextRole · 2.0', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
