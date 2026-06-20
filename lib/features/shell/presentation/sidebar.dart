import 'package:flutter/material.dart';
import '../../../core/theme/zournia_theme.dart';

enum AppView { shell, dashboard, workspace, settings }

class ShellSidebar extends StatefulWidget {
  final List<String> workspaces;
  final int activeWorkspaceIndex;
  final AppView currentView;
  final ValueChanged<AppView> onViewChanged;
  final ValueChanged<int> onWorkspaceChanged;
  final VoidCallback onAddWorkspace;
  final ValueChanged<int> onRemoveWorkspace;

  const ShellSidebar({
    super.key,
    required this.workspaces,
    required this.activeWorkspaceIndex,
    required this.currentView,
    required this.onViewChanged,
    required this.onWorkspaceChanged,
    required this.onAddWorkspace,
    required this.onRemoveWorkspace,
  });

  @override
  State<ShellSidebar> createState() => _ShellSidebarState();
}

class _ShellSidebarState extends State<ShellSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: ZourniaTheme.shellSurface, border: Border(right: BorderSide(color: ZourniaTheme.shellBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & workspace tabs
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset('assets/z_logo.png', width: 20, height: 20, fit: BoxFit.cover)),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.workspaces.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final name = entry.value;
                        final isActive = idx == widget.activeWorkspaceIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => widget.onWorkspaceChanged(idx),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? ZourniaTheme.shellBorder : Colors.transparent,
                                border: Border.all(color: isActive ? ZourniaTheme.shellBorderSub : Colors.transparent),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(children: [
                                Text(name, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                                if (widget.workspaces.length > 1) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => widget.onRemoveWorkspace(idx),
                                    child: Icon(Icons.close, color: isActive ? Colors.white54 : Colors.white30, size: 12),
                                  ),
                                ],
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(onTap: widget.onAddWorkspace, borderRadius: BorderRadius.circular(4), child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.add, color: Colors.white54, size: 16))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('NAVIGATION', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const Spacer(),
              const Icon(Icons.grid_view_rounded, color: Colors.white54, size: 12),
            ]),
          ),
          const SizedBox(height: 12),
          _SidebarNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => widget.onViewChanged(AppView.dashboard), isActive: widget.currentView == AppView.dashboard),
          _SidebarNavItem(icon: Icons.category_outlined, label: 'Workspace Canvas', onTap: () => widget.onViewChanged(AppView.workspace), isActive: widget.currentView == AppView.workspace),
          _SidebarNavItem(icon: Icons.chat_bubble_outline, label: 'Chat Shell', onTap: () => widget.onViewChanged(AppView.shell), isActive: widget.currentView == AppView.shell),
          const Spacer(),
          _SidebarNavItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => widget.onViewChanged(AppView.settings), isActive: widget.currentView == AppView.settings),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _SidebarNavItem({required this.icon, required this.label, required this.onTap, required this.isActive});

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;
  Color get _fgColor => widget.isActive || _hovered ? Colors.white : Colors.white54;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isActive ? ZourniaTheme.shellCard : _hovered ? ZourniaTheme.shellSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(widget.icon, size: 16, color: _fgColor),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _fgColor, fontSize: 12, fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
