import 'package:flutter/material.dart';
import '../../../core/theme/zournia_theme.dart';

class AiHudPanel extends StatelessWidget {
  const AiHudPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZourniaTheme.shellBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded, color: Colors.white.withValues(alpha: 0.12), size: 48),
            const SizedBox(height: 12),
            Text(
              'HUD_TERMINAL // OFFLINE',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
