import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'layout_breakpoints.dart';

class OnyxPageScaffold extends StatelessWidget {
  final Widget child;

  const OnyxPageScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0C1220)),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x180F5EA8), Color(0x00040A16)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x100F4A87), Color(0x00040A16)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
    if (Scaffold.maybeOf(context) != null) {
      return surface;
    }
    return Scaffold(backgroundColor: const Color(0xFF040A16), body: surface);
  }
}

class OnyxPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const OnyxPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final titleCard = Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF17324F).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final actionCard = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (actions.isEmpty) {
          return titleCard;
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleCard, const SizedBox(height: 8), actionCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleCard),
            const SizedBox(width: 8),
            actionCard,
          ],
        );
      },
    );
  }
}

class OnyxSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool flexibleChild;

  const OnyxSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding,
    this.flexibleChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canConstrainBody = constraints.hasBoundedHeight;
        final phoneLayout = isHandsetLayout(context);
        final compactBoundedLayout =
            canConstrainBody && constraints.maxHeight < 140;
        if (compactBoundedLayout) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B76B6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE6F1FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              child,
            ],
          );
          return Container(
            width: double.infinity,
            padding: padding ?? const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A2B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF223244)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: phoneLayout
                ? content
                : SingleChildScrollView(child: content),
          );
        }
        final body = flexibleChild
            ? Expanded(child: child)
            : canConstrainBody && !phoneLayout
            ? Expanded(child: SingleChildScrollView(child: child))
            : child;
        return Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF223244)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B76B6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE6F1FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              body,
            ],
          ),
        );
      },
    );
  }
}

class OnyxTruncationHint extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final String subject;
  final String hiddenDescriptor;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const OnyxTruncationHint({
    super.key,
    required this.visibleCount,
    required this.totalCount,
    required this.subject,
    this.hiddenDescriptor = 'older rows',
    this.color = const Color(0xFF8EA4C2),
    this.fontSize = 11,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final hiddenCount = totalCount - visibleCount;
    if (hiddenCount <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      'Showing $visibleCount of $totalCount $subject. '
      '$hiddenCount $hiddenDescriptor hidden.',
      style: GoogleFonts.inter(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}

class OnyxSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const OnyxSummaryStat({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223244)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration onyxWorkspaceSurfaceDecoration() {
  return BoxDecoration(
    color: const Color(0xFF0E1A2B),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFF223244)),
    boxShadow: const [
      BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxSelectableRowSurfaceDecoration({required bool isSelected}) {
  return BoxDecoration(
    color: isSelected ? const Color(0xFF11243A) : const Color(0xFF0E1A2B),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isSelected ? const Color(0xFF5D91C6) : const Color(0xFF223244),
    ),
    boxShadow: isSelected
        ? const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ]
        : null,
  );
}

BoxDecoration onyxPanelSurfaceDecoration({double radius = 12}) {
  return BoxDecoration(
    color: const Color(0xFF0E1A2B),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFF223244)),
    boxShadow: const [
      BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxForensicSurfaceCardDecoration() {
  return BoxDecoration(
    color: const Color(0xFF0E1A2B),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFF223244)),
    boxShadow: const [
      BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxForensicRowDecoration({required bool isSelected}) {
  return BoxDecoration(
    color: isSelected ? const Color(0xFF11243A) : const Color(0xFF0E1A2B),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isSelected ? const Color(0xFF5D91C6) : const Color(0xFF223244),
    ),
    boxShadow: isSelected
        ? const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ]
        : null,
  );
}

class OnyxEmptyState extends StatelessWidget {
  final String label;

  const OnyxEmptyState({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF223244)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
