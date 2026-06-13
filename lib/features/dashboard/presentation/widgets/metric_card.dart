import 'package:flutter/material.dart';
import 'package:zournia_pc/core/theme/zournia_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? indicator;
  const MetricCard({super.key, required this.label, required this.value, this.indicator});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZourniaTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZourniaTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ZourniaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: TextStyle(color: ZourniaTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              if (indicator != null) ...[
                const SizedBox(width: 8),
                indicator!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
