import 'dart:io';

import 'package:flutter/material.dart';

enum EditorElementType {
  image,
  text,
  brush,
}

double _round1(double v) => (v * 10).round() / 10;

class BrushStroke {
  final Color color;
  final double width;
  final bool erase;

  final List<Offset> points = [];
  final Path path = Path();

  BrushStroke({
    required this.color,
    required this.width,
    this.erase = false,
  });

  void add(Offset p) {
    points.add(p);
    final n = points.length;

    if (n == 1) {
      path.moveTo(p.dx, p.dy);
    } else if (n == 2) {
      final a = points[0];
      path.lineTo((a.dx + p.dx) / 2, (a.dy + p.dy) / 2);
    } else {
      final prev = points[n - 2];
      path.quadraticBezierTo(
        prev.dx,
        prev.dy,
        (prev.dx + p.dx) / 2,
        (prev.dy + p.dy) / 2,
      );
    }
  }

  void finish() {
    if (points.length >= 2) {
      path.lineTo(points.last.dx, points.last.dy);
    }
  }

  Map<String, dynamic> toJson() {
    final flat = <double>[];
    for (final p in points) {
      flat
        ..add(_round1(p.dx))
        ..add(_round1(p.dy));
    }

    return {
      'color': color.toARGB32(),
      'width': _round1(width),
      'erase': erase,
      'points': flat,
    };
  }

  factory BrushStroke.fromJson(Map<String, dynamic> json) {
    final stroke = BrushStroke(
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
      erase: json['erase'] as bool? ?? false,
    );

    final flat = (json['points'] as List).cast<num>();
    for (var i = 0; i + 1 < flat.length; i += 2) {
      stroke.add(Offset(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    stroke.finish();

    return stroke;
  }
}

class EditorElement {
  final String id;
  final EditorElementType type;

  File? image;
  String text;

  Offset position;
  double scale;
  double rotation;

  Color textColor;
  double fontSize;
  bool visible;
  final List<BrushStroke> strokes;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  EditorElement({
    required this.id,
    required this.type,
    this.image,
    this.text = '',
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textColor = Colors.black,
    this.fontSize = 42,
    this.visible = true,
    List<BrushStroke>? strokes,
  }) : strokes = strokes ?? [];

  void notifyChanged() {
    revision.value++;
  }

  EditorElement copy() {
    return EditorElement(
      id: id,
      type: type,
      image: image,
      text: text,
      position: position,
      scale: scale,
      rotation: rotation,
      textColor: textColor,
      fontSize: fontSize,
      visible: visible,
      strokes: List<BrushStroke>.from(strokes),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'text': text,
      'position': [position.dx, position.dy],
      'scale': scale,
      'rotation': rotation,
      'textColor': textColor.toARGB32(),
      'fontSize': fontSize,
      'visible': visible,
      'strokes': [for (final s in strokes) s.toJson()],
    };
  }

  factory EditorElement.fromJson(
      Map<String, dynamic> json, {
        File? image,
      }) {
    final pos = (json['position'] as List).cast<num>();

    return EditorElement(
      id: json['id'] as String,
      type: EditorElementType.values.firstWhere(
            (t) => t.name == json['type'],
        orElse: () => EditorElementType.image,
      ),
      image: image,
      text: json['text'] as String? ?? '',
      position: Offset(pos[0].toDouble(), pos[1].toDouble()),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      textColor: Color(json['textColor'] as int? ?? 0xFF000000),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 42,
      visible: json['visible'] as bool? ?? true,
      strokes: [
        for (final s in (json['strokes'] as List? ?? const []))
          BrushStroke.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}