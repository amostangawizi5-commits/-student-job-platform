import 'package:flutter/material.dart';

class StatisticCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;
  final VoidCallback? onTap;
  final bool compact;
  final bool selected;

  const StatisticCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
    this.onTap,
    this.compact = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final trendLabel = trend?.trim();
    final hasTrend = trendLabel != null && trendLabel.isNotEmpty;
    final trendColor = _trendColor(trendLabel);
    final borderRadius = compact ? 14.0 : 20.0;
    final iconPadding = compact ? 10.0 : 12.0;
    final iconSize = compact ? 20.0 : 24.0;
    final contentPadding = compact ? 14.0 : 18.0;
    final valueFontSize = compact ? 18.0 : 28.0;
    final titleFontSize = compact ? 12.0 : 14.0;
    final cardShadowBlur = compact ? 8.0 : 14.0;
    final cardShadowOffset = compact ? 2.0 : 4.0;
    final subtitleLabel = subtitle?.trim();
    final hasSubtitle = subtitleLabel != null && subtitleLabel.isNotEmpty;
    final iconRadius = compact ? 12.0 : 14.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 92 : 116),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.3 : 0.18),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: selected ? 0.14 : 0.1),
                blurRadius: selected ? cardShadowBlur + 1 : cardShadowBlur,
                offset: Offset(
                  0,
                  selected ? cardShadowOffset + 1 : cardShadowOffset,
                ),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: compact ? 8 : 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(iconRadius),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              value.toString(),
                              style: TextStyle(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                                height: 1.05,
                              ),
                            ),
                          ),
                          if (hasTrend)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: trendColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trendLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: trendColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: compact ? 10 : 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitleLabel,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _trendColor(String? trendLabel) {
    if (trendLabel == null || trendLabel.isEmpty) {
      return Colors.grey;
    }
    if (trendLabel.startsWith('+')) {
      return Colors.green;
    }
    if (trendLabel.startsWith('-')) {
      return Colors.red;
    }
    if (trendLabel.toLowerCase().contains('current')) {
      return Colors.blueGrey;
    }
    return Colors.grey;
  }
}
