import 'package:flutter/material.dart';

import '../../models/editor_element.dart';

class LayerPanel extends StatelessWidget {
  final List<EditorElement> elements;
  final String? selectedElementId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onToggleVisibility;
  final void Function(int oldIndex, int newIndex) onReorder;

  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const LayerPanel({
    super.key,
    required this.elements,
    required this.selectedElementId,
    required this.onSelect,
    required this.onDelete,
    required this.onToggleVisibility,
    required this.onReorder,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final count = elements.length;
    final selectedIndex =
    elements.indexWhere((e) => e.id == selectedElementId);
    final canMoveUp = selectedIndex != -1 && selectedIndex < count - 1;
    final canMoveDown = selectedIndex > 0;

    return Container(
      height: 124,
      color: const Color(0xFF141414),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 6, 0),
            child: Row(
              children: [
                const Text(
                  'Шари',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'утримуй шар, щоб перетягнути',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Вище',
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.flip_to_front),
                ),
                IconButton(
                  tooltip: 'Нижче',
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.flip_to_back),
                ),
              ],
            ),
          ),
          Expanded(
            child: elements.isEmpty
                ? const Center(
              child: Text(
                'Додай фото або текст',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            )
                : ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: count,
              onReorder: onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final element = elements[count - 1 - index];
                return _buildTile(element);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(EditorElement element) {
    final selected = element.id == selectedElementId;

    return GestureDetector(
      key: ValueKey(element.id),
      onTap: () => onSelect(element.id),
      child: Container(
        width: 116,
        margin: const EdgeInsets.only(right: 6, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:
          selected ? const Color(0xFF303030) : const Color(0xFF202020),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? Colors.blueAccent : const Color(0xFF333333),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _iconFor(element.type),
              color: element.visible ? Colors.white70 : Colors.white30,
              size: 19,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _nameFor(element),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: element.visible ? Colors.white : Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onToggleVisibility(element.id),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      element.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white60,
                      size: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDelete(element.id),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(EditorElementType type) {
    switch (type) {
      case EditorElementType.image:
        return Icons.image_outlined;
      case EditorElementType.text:
        return Icons.text_fields;
      case EditorElementType.brush:
        return Icons.brush_outlined;
    }
  }

  String _nameFor(EditorElement element) {
    switch (element.type) {
      case EditorElementType.image:
        return 'Зображення';
      case EditorElementType.text:
        return element.text.isEmpty ? 'Текст' : element.text;
      case EditorElementType.brush:
        return 'Малювання';
    }
  }
}