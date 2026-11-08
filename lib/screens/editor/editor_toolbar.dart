import 'package:flutter/material.dart';

import '../../app/theme.dart';

class EditorToolbar extends StatelessWidget {
  final int selectedTool;
  final ValueChanged<int> onToolSelected;

  const EditorToolbar({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
  });

  static const int moveTool = 0;
  static const int handTool = 1;
  static const int imageTool = 2;
  static const int textTool = 3;
  static const int cropTool = 4;
  static const int brushTool = 5;
  static const int eraserTool = 6;
  static const int shapeTool = 7;

  static const List<EditorTool> tools = [
    EditorTool(
      icon: Icons.pan_tool_outlined,
      selectedIcon: Icons.pan_tool,
      name: 'Рух',
    ),
    EditorTool(
      icon: Icons.zoom_out_map_outlined,
      selectedIcon: Icons.zoom_out_map,
      name: 'Вигляд',
    ),
    EditorTool(
      icon: Icons.image_outlined,
      selectedIcon: Icons.image,
      name: 'Фото',
    ),
    EditorTool(
      icon: Icons.text_fields_outlined,
      selectedIcon: Icons.text_fields,
      name: 'Текст',
    ),
    EditorTool(
      icon: Icons.crop_outlined,
      selectedIcon: Icons.crop,
      name: 'Обрізка',
    ),
    EditorTool(
      icon: Icons.brush_outlined,
      selectedIcon: Icons.brush,
      name: 'Пензель',
    ),
    EditorTool(
      icon: Icons.cleaning_services_outlined,
      selectedIcon: Icons.cleaning_services,
      name: 'Гумка',
    ),
    EditorTool(
      icon: Icons.crop_square_outlined,
      selectedIcon: Icons.crop_square,
      name: 'Фігура',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            final selected = selectedTool == index;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToolSelected(index),
              child: Container(
                width: 68,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? tool.selectedIcon : tool.icon,
                      size: 23,
                      color: selected
                          ? AppTheme.primary
                          : Colors.white70,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EditorTool {
  final IconData icon;
  final IconData selectedIcon;
  final String name;

  const EditorTool({
    required this.icon,
    required this.selectedIcon,
    required this.name,
  });
}