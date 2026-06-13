import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/theme/zournia_theme.dart';

class ShellTitleBar extends StatelessWidget {
  final String title;
  final String subtitle;
  const ShellTitleBar({super.key, this.title = 'ZOURNIA', this.subtitle = '// WORKSPACE_CORE'});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    
    Widget content = Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.transparent,
      child: Row(
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: ZourniaTheme.shellAccent, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: ZourniaTheme.shellText, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(width: 8),
            Text(subtitle, style: TextStyle(color: ZourniaTheme.shellTextMuted, fontSize: 10, letterSpacing: 1)),
          ]),
          if (isDesktop) ...[
            const Spacer(),
            _btn(Icons.minimize_rounded, () => windowManager.minimize()),
            _btn(Icons.crop_square_rounded, () async { final m = await windowManager.isMaximized(); m ? windowManager.unmaximize() : windowManager.maximize(); }),
            _btn(Icons.close_rounded, () => windowManager.close()),
          ],
        ],
      ),
    );

    if (isDesktop) {
      return DragToMoveArea(child: content);
    }
    return content;
  }

  Widget _btn(IconData i, VoidCallback f) => IconButton(icon: Icon(i, color: ZourniaTheme.shellTextMuted, size: 14), hoverColor: Colors.white10, onPressed: f);
}
