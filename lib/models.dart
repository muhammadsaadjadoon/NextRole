const stages = [
  'Applied',
  'Under Review',
  'Shortlisted',
  'Selected',
  'Rejected',
  'Withdrawn',
];
const jobTypes = ['Full-time', 'Part-time', 'Internship', 'Contract'];
const workModes = ['Remote', 'On-site', 'Hybrid'];
const fields = [
  'Engineering',
  'Design',
  'Marketing',
  'Business',
  'Data',
  'Other',
];
String dateLabel(String value) {
  final d = DateTime.tryParse(value);
  return d == null ? 'Not specified' : '${d.day}/${d.month}/${d.year}';
}

bool available(Map<String, dynamic> j) =>
    j['approval'] == 'approved' &&
    j['open'] == true &&
    (DateTime.tryParse(
          j['deadline'] as String? ?? '',
        )?.isAfter(DateTime.now()) ??
        false);
String applicationId(String jobId, String uid) => '${jobId}_$uid';
List<Map<String, dynamic>> filterJobs(
  List<Map<String, dynamic>> jobs, {
  String search = '',
  String type = 'All',
  String mode = 'All',
  String field = 'All',
  String location = '',
}) {
  final q = search.trim().toLowerCase();
  return jobs
      .where(
        (j) =>
            available(j) &&
            '${j['title']} ${j['company']} ${j['skills']} ${j['description']}'
                .toLowerCase()
                .contains(q) &&
            (type == 'All' || j['type'] == type) &&
            (mode == 'All' || j['mode'] == mode) &&
            (field == 'All' || j['field'] == field) &&
            (j['location'] as String).toLowerCase().contains(
              location.trim().toLowerCase(),
            ),
      )
      .toList()
    ..sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );
}

Map<String, dynamic> newProfile(String name, String email, String role) => {
  'name': name,
  'email': email,
  'role': role,
  'active': true,
  'companyApproved': false,
  'headline': '',
  'phone': '',
  'location': '',
  'bio': '',
  'skills': '',
  'education': '',
  'experience': '',
  'company': '',
  'website': '',
  'photo': '',
  'saved': <String>[],
};

String firstName(String name) =>
    name.trim().isEmpty ? 'there' : name.trim().split(RegExp(r'\s+')).first;
int profileCompletion(Map<String, dynamic> profile) {
  const keys = [
    'name',
    'headline',
    'location',
    'skills',
    'education',
    'experience',
  ];
  return (keys
              .where((k) => (profile[k] as String? ?? '').trim().isNotEmpty)
              .length /
          keys.length *
          100)
      .round();
}

int skillMatches(Map<String, dynamic> job, Map<String, dynamic> profile) {
  final skills = (profile['skills'] as String? ?? '')
      .toLowerCase()
      .split(RegExp(r'[,;\n]'))
      .map((v) => v.trim())
      .where((v) => v.length >= 2)
      .toSet();
  final required = (job['skills'] as String? ?? '').toLowerCase();
  return skills.where(required.contains).length;
}
