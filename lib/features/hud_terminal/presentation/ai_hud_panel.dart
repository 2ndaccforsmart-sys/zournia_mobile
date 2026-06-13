import 'package:flutter/material.dart';
import 'package:zournia_pc/core/theme/zournia_theme.dart';

class AiHudPanel extends StatelessWidget {
  const AiHudPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZourniaTheme.shellBg,
      child: Center(
        child: Text(
          'HUD_TERMINAL // OFFLINE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.12),
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
