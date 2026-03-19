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
                Text(title, style: titleStyle),
                const SizedBox(height: 4),
                Text(endpointLabel, style: endpointStyle),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: primaryChips),
                const SizedBox(height: 8),
                Text(
                  lastSeenLabel.startsWith(':')
                      ? 'Last seen$lastSeenLabel'
                      : 'Last seen $lastSeenLabel',
                  style: lastSeenStyle,
                ),
                if ((statusDetailText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    statusDetailText!,
                    style: statusDetailStyle ?? noteStyle,
                  ),
                ],
                if ((noteText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(noteText!, style: noteStyle),
                ],
                if ((latestText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (onLatestTap == null)
                    Text(
                      latestText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: latestStyle,
                    )
                  else
                    InkWell(
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
                    ),
                ],
                if (secondaryChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: secondaryChips),
                ],
                if (actionChildren.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: actionChildren),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
