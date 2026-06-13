// lib/features/ui_components/dropdown_menu.dart
import 'package:flutter/material.dart';

class CustomDropdownMenu<T> extends StatefulWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemLabel;
  final Color accentColor;
  final TextStyle? textStyle;

  const CustomDropdownMenu({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
    this.accentColor = const Color(0xFFE5E8ED),
    this.textStyle,
  });

  @override
  State<CustomDropdownMenu<T>> createState() => _CustomDropdownMenuState<T>();
}

class _CustomDropdownMenuState<T> extends State<CustomDropdownMenu<T>> {
  final MenuController _controller = MenuController();
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.textStyle ?? const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );

    final String selectedLabel = widget.itemLabel(widget.value);
    final bool isSelectedSettings = selectedLabel == 'Settings';

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF0D0D0F)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        elevation: WidgetStateProperty.all(2.0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
        ),
      ),
      menuChildren: () {
        final List<Widget> children = [];
        for (var i = 0; i < widget.items.length; i++) {
          final T item = widget.items[i];
          final String label = widget.itemLabel(item);
          final bool isSelected = item == widget.value;
          final bool isSettings = label == 'Settings';

          if (isSettings && i > 0) {
            children.add(
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.white.withValues(alpha: 0.08),
              ),
            );
          }

          // Resolve Icon
          IconData? iconData;
          if (label.contains('Qwen')) {
            iconData = Icons.code_rounded;
          } else if (label.contains('Gemini')) {
            iconData = Icons.auto_awesome_rounded;
          } else if (label.contains('Auto')) {
            iconData = Icons.psychology_outlined;
          } else if (label.contains('Settings')) {
            iconData = Icons.settings_outlined;
          } else {
            iconData = Icons.smart_toy_outlined;
          }

          final Color itemColor = isSelected 
              ? Colors.white 
              : Colors.white70;

          children.add(
            MenuItemButton(
              onPressed: () {
                widget.onChanged(item);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (isSelected) {
                    return Colors.white.withValues(alpha: 0.1);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return Colors.white.withValues(alpha: 0.04);
                  }
                  return Colors.transparent;
                }),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 14,
                    color: isSelected 
                        ? Colors.white 
                        : Colors.white38,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: textStyle.copyWith(
                      color: itemColor,
                      fontWeight: (isSelected || isSettings) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return children;
      }(),
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              borderRadius: BorderRadius.circular(6),
              hoverColor: Colors.white.withValues(alpha: 0.04),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: controller.isOpen ? const Color(0xFF141416) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: controller.isOpen
                        ? widget.accentColor
                        : (_isHovered
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelectedSettings) ...[
                      const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      selectedLabel,
                      style: textStyle.copyWith(
                        color: controller.isOpen ? widget.accentColor : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: controller.isOpen ? widget.accentColor : Colors.white38,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}