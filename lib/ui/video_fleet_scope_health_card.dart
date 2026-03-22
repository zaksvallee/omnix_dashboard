import 'package:flutter/material.dart';

class VideoFleetScopeHealthCard extends StatelessWidget {
  final String title;
  final String endpointLabel;
  final String lastSeenLabel;
  final TextStyle titleStyle;
  final TextStyle endpointStyle;
  final TextStyle lastSeenStyle;
  final TextStyle noteStyle;
  final TextStyle latestStyle;
  final TextStyle? statusDetailStyle;
  final List<Widget> primaryChips;
  final List<Widget> secondaryChips;
  final List<Widget> actionChildren;
  final Widget? headerChild;
  final Widget? identityChild;
  final bool hideDefaultEndpoint;
  final bool hideDefaultLastSeen;
  final String? primaryGroupLabel;
  final Color? primaryGroupAccent;
  final Key? primaryGroupKey;
  final String? secondaryGroupLabel;
  final Color? secondaryGroupAccent;
  final Key? secondaryGroupKey;
  final String? contextGroupLabel;
  final Color? contextGroupAccent;
  final Key? contextGroupKey;
  final String? latestGroupLabel;
  final Color? latestGroupAccent;
  final Key? latestGroupKey;
  final String? actionsGroupLabel;
  final Color? actionsGroupAccent;
  final Key? actionsGroupKey;
  final String? noteText;
  final String? latestText;
  final String? statusDetailText;
  final VoidCallback? onTap;
  final VoidCallback? onLatestTap;
  final BoxDecoration decoration;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const VideoFleetScopeHealthCard({
    super.key,
    required this.title,
    required this.endpointLabel,
    required this.lastSeenLabel,
    required this.titleStyle,
    required this.endpointStyle,
    required this.lastSeenStyle,
    required this.noteStyle,
    required this.latestStyle,
    this.statusDetailStyle,
    required this.primaryChips,
    required this.secondaryChips,
    required this.actionChildren,
    this.headerChild,
    this.identityChild,
    this.hideDefaultEndpoint = false,
    this.hideDefaultLastSeen = false,
    this.primaryGroupLabel,
    this.primaryGroupAccent,
    this.primaryGroupKey,
    this.secondaryGroupLabel,
    this.secondaryGroupAccent,
    this.secondaryGroupKey,
    this.contextGroupLabel,
    this.contextGroupAccent,
    this.contextGroupKey,
    this.latestGroupLabel,
    this.latestGroupAccent,
    this.latestGroupKey,
    this.actionsGroupLabel,
    this.actionsGroupAccent,
    this.actionsGroupKey,
    required this.decoration,
    required this.constraints,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = 10,
    this.noteText,
    this.latestText,
    this.statusDetailText,
    this.onTap,
    this.onLatestTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headerChild != null) ...[
                  headerChild!,
                  const SizedBox(height: 10),
                ],
                Text(title, style: titleStyle),
                if (identityChild != null) ...[
                  const SizedBox(height: 6),
                  identityChild!,
                ] else if (!hideDefaultEndpoint) ...[
                  const SizedBox(height: 4),
                  Text(endpointLabel, style: endpointStyle),
                ],
                const SizedBox(height: 8),
                _chipGroup(
                  children: primaryChips,
                  label: primaryGroupLabel,
                  accent: primaryGroupAccent,
                  groupKey: primaryGroupKey,
                ),
                if (!hideDefaultLastSeen) ...[
                  const SizedBox(height: 8),
                  Text(
                    lastSeenLabel.startsWith(':')
                        ? 'Last seen$lastSeenLabel'
                        : 'Last seen $lastSeenLabel',
                    style: lastSeenStyle,
                  ),
                ],
                ..._buildContextSection(),
                ..._buildLatestSection(),
                if (secondaryChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _chipGroup(
                    children: secondaryChips,
                    label: secondaryGroupLabel,
                    accent: secondaryGroupAccent,
                    groupKey: secondaryGroupKey,
                  ),
                ],
                ..._buildActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipGroup({
    required List<Widget> children,
    String? label,
    Color? accent,
    Key? groupKey,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    if ((label ?? '').trim().isEmpty) {
      return Wrap(spacing: 6, runSpacing: 6, children: children);
    }
    final groupAccent = accent ?? const Color(0xFF9AB1CF);
    return Container(
      key: groupKey,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: groupAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: groupAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label!,
            style: lastSeenStyle.copyWith(
              color: groupAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: children),
        ],
      ),
    );
  }

  List<Widget> _buildContextSection() {
    final contextChildren = <Widget>[];
    if ((statusDetailText ?? '').trim().isNotEmpty) {
      contextChildren.add(
        Text(statusDetailText!, style: statusDetailStyle ?? noteStyle),
      );
    }
    if ((noteText ?? '').trim().isNotEmpty) {
      if (contextChildren.isNotEmpty) {
        contextChildren.add(const SizedBox(height: 8));
      }
      contextChildren.add(Text(noteText!, style: noteStyle));
    }
    if (contextChildren.isEmpty) {
      return const <Widget>[];
    }
    return [
      const SizedBox(height: 8),
      if ((contextGroupLabel ?? '').trim().isNotEmpty)
        _contentGroup(
          children: contextChildren,
          label: contextGroupLabel!,
          accent: contextGroupAccent,
          groupKey: contextGroupKey,
        )
      else
        ...contextChildren,
    ];
  }

  List<Widget> _buildLatestSection() {
    if ((latestText ?? '').trim().isEmpty) {
      return const <Widget>[];
    }
    final latestChild = onLatestTap == null
        ? Text(
            latestText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: latestStyle,
          )
        : InkWell(
            onTap: onLatestTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                latestText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: latestStyle.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: latestStyle.color,
                ),
              ),
            ),
          );
    return [
      const SizedBox(height: 8),
      if ((latestGroupLabel ?? '').trim().isNotEmpty)
        _contentGroup(
          children: [latestChild],
          label: latestGroupLabel!,
          accent: latestGroupAccent,
          groupKey: latestGroupKey,
        )
      else
        latestChild,
    ];
  }

  List<Widget> _buildActionsSection() {
    if (actionChildren.isEmpty) {
      return const <Widget>[];
    }
    final actionsWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actionChildren,
    );
    return [
      const SizedBox(height: 10),
      if ((actionsGroupLabel ?? '').trim().isNotEmpty)
        _contentGroup(
          children: [actionsWrap],
          label: actionsGroupLabel!,
          accent: actionsGroupAccent,
          groupKey: actionsGroupKey,
        )
      else
        actionsWrap,
    ];
  }

  Widget _contentGroup({
    required List<Widget> children,
    required String label,
    Color? accent,
    Key? groupKey,
  }) {
    final groupAccent = accent ?? const Color(0xFF9AB1CF);
    return Container(
      key: groupKey,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: groupAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: groupAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: lastSeenStyle.copyWith(
              color: groupAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
