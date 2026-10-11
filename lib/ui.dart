import 'package:flutter/material.dart';

const ink = Color(0xff06264e), accent = Color(0xff00ccb0);

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .12),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = accent});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      softWrap: true,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? color
            : Color.lerp(color, Colors.black, .35),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.search_off_rounded,
    this.action,
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 44, color: accent),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(child: action!),
        ],
      ],
    ),
  );
}

class AdaptiveTiles extends StatelessWidget {
  const AdaptiveTiles({
    super.key,
    required this.children,
    this.minWidth = 300,
    this.gap = 16,
  });
  final List<Widget> children;
  final double minWidth, gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = ((c.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, 4);
      final width = (c.maxWidth - (count - 1) * gap) / count;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

Widget dropdown(
  String label,
  String value,
  List<String> options,
  void Function(String) changed,
) => DropdownButtonFormField<String>(
  key: ValueKey('$label:$value'),
  initialValue: value,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: options
      .map(
        (v) => DropdownMenuItem(
          value: v,
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: (v) {
    if (v != null) {
      changed(v);
    }
  },
);
Color statusColor(String status) => switch (status) {
  'Selected' || 'approved' => accent,
  'Rejected' || 'rejected' => const Color(0xffef7187),
  'Shortlisted' => const Color(0xff9b8cff),
  'Under Review' || 'pending' => const Color(0xffd99630),
  'Withdrawn' => const Color(0xff8192a6),
  _ => const Color(0xff4489de),
};

class CompanyMark extends StatelessWidget {
  const CompanyMark(this.name, {super.key, this.size = 46});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      name.trim().isEmpty ? 'N' : name.trim().substring(0, 1).toUpperCase(),
      style: TextStyle(
        fontSize: size * .4,
        fontWeight: FontWeight.w800,
        color: accent,
      ),
    ),
  );
}
