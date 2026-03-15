import 'package:flutter/material.dart';

import 'video_fleet_scope_health_sections.dart';

class VideoFleetScopeHealthPanel extends StatelessWidget {
  final String title;
  final TextStyle titleStyle;
  final TextStyle sectionLabelStyle;
  final VideoFleetScopeHealthSections sections;
  final List<Widget> summaryChildren;
  final List<Widget> actionableChildren;
  final List<Widget> watchOnlyChildren;
  final VideoFleetWatchActionDrilldown? activeWatchActionDrilldown;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration decoration;
  final double sectionSpacing;
  final double cardSpacing;
  final double runSpacing;

  const VideoFleetScopeHealthPanel({
    super.key,
    required this.title,
    required this.titleStyle,
    required this.sectionLabelStyle,
    required this.sections,
    required this.summaryChildren,
    required this.actionableChildren,
    required this.watchOnlyChildren,
    this.activeWatchActionDrilldown,
    required this.padding,
    required this.decoration,
    this.margin,
    this.sectionSpacing = 10,
    this.cardSpacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: summaryChildren),
          SizedBox(height: sectionSpacing),
          _sectionLabel(
            activeWatchActionDrilldown?.actionableSectionTitle ?? 'ACTIONABLE',
            sections.actionableScopes.length,
            sections.actionableLabelFor(activeWatchActionDrilldown),
          ),
          if (actionableChildren.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: cardSpacing,
              runSpacing: runSpacing,
              children: actionableChildren,
            ),
          ],
          SizedBox(height: sectionSpacing),
          _sectionLabel(
            activeWatchActionDrilldown?.watchOnlySectionTitle ?? 'WATCH-ONLY',
            sections.watchOnlyScopes.length,
            sections.watchOnlyLabelFor(activeWatchActionDrilldown),
          ),
          if (watchOnlyChildren.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: cardSpacing,
              runSpacing: runSpacing,
              children: watchOnlyChildren,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, int count, String detail) {
    return Text('$title ($count) • $detail', style: sectionLabelStyle);
  }
}
