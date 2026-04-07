import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'layout_breakpoints.dart';

const _onyxCanvasColor = Color(0xFFF5F7FB);
const _onyxPanelColor = Color(0xFFFFFFFF);
const _onyxPanelTint = Color(0xFFF7FAFE);
const _onyxPanelBorder = Color(0xFFD7E1EC);
const _onyxSelectedPanel = Color(0xFFE8F1FF);
const _onyxSelectedBorder = Color(0xFF9EC1E8);
const _onyxTitleColor = Color(0xFF142235);
const _onyxBodyColor = Color(0xFF516882);
const _onyxMutedColor = Color(0xFF6A7D93);
const _onyxAccentBlue = Color(0xFF5B86B1);

Color _softenHeroColor(Color color) {
  return Color.lerp(color, Colors.white, 0.82)!;
}

class OnyxPageScaffold extends StatelessWidget {
  final Widget child;

  const OnyxPageScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: const BoxDecoration(color: _onyxCanvasColor),
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
                    colors: [Color(0x225B86B1), Color(0x00F5F7FB)],
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
                    colors: [Color(0x145B86B1), Color(0x00F5F7FB)],
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
    return Scaffold(backgroundColor: _onyxCanvasColor, body: surface);
  }
}

class OnyxPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final IconData? icon;
  final Color? iconColor;

  const OnyxPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null && iconColor != null) {
      return _iconLayout();
    }
    final titleCard = Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: _onyxPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _onyxPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: _onyxAccentBlue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _onyxTitleColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _onyxMutedColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final actionCard = Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: _onyxPanelTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _onyxPanelBorder),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
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
            children: [titleCard, const SizedBox(height: 6), actionCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleCard),
            const SizedBox(width: 6),
            actionCard,
          ],
        );
      },
    );
  }

  Widget _iconLayout() {
    final color = iconColor!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _onyxTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _onyxMutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          ...actions,
        ],
      ],
    );
  }
}

class OnyxStoryMetric {
  final String label;
  final String value;
  final Color foreground;
  final Color background;
  final Color border;

  const OnyxStoryMetric({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class OnyxStoryHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final List<OnyxStoryMetric> metrics;
  final List<Widget> actions;
  final Widget? banner;
  final String? eyebrow;

  const OnyxStoryHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.metrics = const <OnyxStoryMetric>[],
    this.actions = const <Widget>[],
    this.banner,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    final softenedGradient = gradientColors
        .map(_softenHeroColor)
        .toList(growable: false);
    final accentColor = gradientColors.isNotEmpty
        ? Color.lerp(gradientColors.first, _onyxAccentBlue, 0.45)!
        : _onyxAccentBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: softenedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _onyxPanelBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1040;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _onyxSelectedPanel,
                      border: Border.all(color: _onyxSelectedBorder),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Text(
                            eyebrow!,
                            style: GoogleFonts.inter(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: _onyxTitleColor,
                            fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            height: 0.96,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: _onyxMutedColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: metrics.map(_metricChip).toList(growable: false),
                ),
              ],
            ],
          );
          final actionsBlock = actions.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (actions.isEmpty)
                titleBlock
              else if (compact) ...[
                titleBlock,
                const SizedBox(height: 10),
                actionsBlock,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: actionsBlock,
                    ),
                  ],
                ),
              if (banner != null) ...[const SizedBox(height: 10), banner!],
            ],
          );
        },
      ),
    );
  }

  Widget _metricChip(OnyxStoryMetric metric) {
    final labelColor = metric.background.computeLuminance() < 0.55
        ? Colors.white
        : _onyxBodyColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: metric.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: metric.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${metric.value} ',
              style: GoogleFonts.inter(
                color: metric.foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: metric.label,
              style: GoogleFonts.inter(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: _onyxAccentBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _onyxTitleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: _onyxMutedColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              child,
            ],
          );
          return Container(
            width: double.infinity,
            padding: padding ?? const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _onyxPanelColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _onyxPanelBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A081B33),
                  blurRadius: 14,
                  offset: Offset(0, 5),
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
          padding: padding ?? const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _onyxPanelColor,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _onyxPanelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A081B33),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: _onyxAccentBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _onyxTitleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: _onyxMutedColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              body,
            ],
          ),
        );
      },
    );
  }
}

class OnyxViewportWorkspaceLayout extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Widget header;
  final Widget body;
  final double spacing;
  final bool lockToViewport;

  const OnyxViewportWorkspaceLayout({
    super.key,
    required this.padding,
    required this.maxWidth,
    required this.header,
    required this.body,
    this.spacing = 10,
    this.lockToViewport = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldLock = lockToViewport && constraints.hasBoundedHeight;
        final constrainedContent = OnyxCommandSurface(
          compactDesktopWidth: maxWidth,
          viewportWidth: constraints.maxWidth,
          child: shouldLock
              ? SizedBox(
                  height: _availableViewportHeight(
                    constraints.maxHeight,
                    resolvedPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      SizedBox(height: spacing),
                      Expanded(child: body),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    SizedBox(height: spacing),
                    body,
                  ],
                ),
        );
        if (shouldLock) {
          return Padding(padding: resolvedPadding, child: constrainedContent);
        }
        return SingleChildScrollView(
          padding: resolvedPadding,
          child: constrainedContent,
        );
      },
    );
  }

  double _availableViewportHeight(
    double viewportHeight,
    EdgeInsets resolvedPadding,
  ) {
    final availableHeight = viewportHeight - resolvedPadding.vertical;
    return availableHeight > 0 ? availableHeight : 0;
  }
}

class OnyxCommandSurface extends StatelessWidget {
  final Widget child;
  final double compactDesktopWidth;
  final double? viewportWidth;
  final AlignmentGeometry alignment;

  const OnyxCommandSurface({
    super.key,
    required this.child,
    required this.compactDesktopWidth,
    this.viewportWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedViewportWidth = viewportWidth ?? constraints.maxWidth;
        final resolvedMaxWidth = commandSurfaceMaxWidth(
          context,
          compactDesktopWidth: compactDesktopWidth,
          viewportWidth: resolvedViewportWidth,
        );
        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

Widget onyxBoundedPanelBody({
  required BuildContext context,
  required BoxConstraints constraints,
  required Widget child,
  bool flexibleChild = false,
}) {
  if (flexibleChild) {
    return Expanded(child: child);
  }
  if (constraints.hasBoundedHeight && !isHandsetLayout(context)) {
    return Expanded(child: SingleChildScrollView(child: child));
  }
  return child;
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
    this.color = _onyxMutedColor,
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _onyxPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _onyxPanelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A081B33),
            blurRadius: 12,
            offset: Offset(0, 4),
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
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _onyxMutedColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 16,
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
    color: _onyxPanelColor,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _onyxPanelBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x08081B33), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxSelectableRowSurfaceDecoration({required bool isSelected}) {
  return BoxDecoration(
    color: isSelected ? _onyxSelectedPanel : _onyxPanelColor,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isSelected ? _onyxSelectedBorder : _onyxPanelBorder,
    ),
    boxShadow: isSelected
        ? const [
            BoxShadow(
              color: Color(0x08081B33),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ]
        : null,
  );
}

BoxDecoration onyxPanelSurfaceDecoration({double radius = 12}) {
  return BoxDecoration(
    color: _onyxPanelColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _onyxPanelBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x08081B33), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxForensicSurfaceCardDecoration() {
  return BoxDecoration(
    color: _onyxPanelTint,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _onyxPanelBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x08081B33), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration onyxForensicRowDecoration({required bool isSelected}) {
  return BoxDecoration(
    color: isSelected ? _onyxSelectedPanel : _onyxPanelColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isSelected ? _onyxSelectedBorder : _onyxPanelBorder,
    ),
    boxShadow: isSelected
        ? const [
            BoxShadow(
              color: Color(0x08081B33),
              blurRadius: 10,
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
          color: _onyxPanelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _onyxPanelBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: _onyxMutedColor,
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
