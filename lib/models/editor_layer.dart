import 'dart:ui';

enum EditorLayerType {
  image,
  text,
}

class EditorLayer {
  final String id;

  String name;

  EditorLayerType type;

  String? imagePath;

  String? text;

  Offset position;

  double scale;

  double rotation;

  bool visible;

  EditorLayer({
    required this.id,
    required this.name,
    required this.type,
    this.imagePath,
    this.text,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.visible = true,
  });

  EditorLayer copyWith({
    String? name,
    EditorLayerType? type,
    String? imagePath,
    String? text,
    Offset? position,
    double? scale,
    double? rotation,
    bool? visible,
  }) {
    return EditorLayer(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      text: text ?? this.text,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toMap({
    required int projectId,
    required int zIndex,
  }) {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'type': type.name,
      'image_path': imagePath,
      'text_content': text,
      'pos_x': position.dx,
      'pos_y': position.dy,
      'scale': scale,
      'rotation': rotation,
      'is_visible': visible ? 1 : 0,
      'z_index': zIndex,
    };
  }

  factory EditorLayer.fromMap(Map<String, dynamic> map) {
    return EditorLayer(
      id: map['id'] as String,
      name: map['name'] as String,
      type: EditorLayerType.values.byName(map['type'] as String),
      imagePath: map['image_path'] as String?,
      text: map['text_content'] as String?,
      position: Offset(
        (map['pos_x'] as num).toDouble(),
        (map['pos_y'] as num).toDouble(),
      ),
      scale: (map['scale'] as num).toDouble(),
      rotation: (map['rotation'] as num).toDouble(),
      visible: (map['is_visible'] as int) == 1,
    );
  }
}