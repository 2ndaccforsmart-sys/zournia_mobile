import 'package:flutter/material.dart';
import '../../../core/theme/zournia_theme.dart';

class WorkspaceCanvas extends StatelessWidget {
  const WorkspaceCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZourniaTheme.shellBg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined, color: ZourniaTheme.shellAccent, size: 20),
              const SizedBox(width: 10),
              const Text(
                'WORKSPACE CANVAS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ZourniaTheme.shellAccent.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspaces_outlined, color: Colors.white.withValues(alpha: 0.12), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'WORKSPACE // EMPTY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Multi-workspace canvas coming soon.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.08),
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
