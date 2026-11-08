import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/editor_element.dart';

double _defaultViewScale() => 1.0;

class EditorCanvas extends StatelessWidget {
  final double canvasWidth;
  final double canvasHeight;
  final List<EditorElement> elements;
  final String? selectedElementId;
  final ValueChanged<String> onSelect;
  final void Function(
      String id,
      Offset position,
      double scale,
      double rotation,
      ) onTransform;
  final VoidCallback onTransformEnd;
  final VoidCallback onDeselect;

  final bool brushMode;
  final ValueChanged<Offset>? onBrushStart;
  final ValueChanged<Offset>? onBrushUpdate;
  final VoidCallback? onBrushEnd;

  /// Поточний зум полотна (потрібен, щоб шар рухався разом із пальцем).
  final double Function() viewScale;

  const EditorCanvas({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.elements,
    required this.selectedElementId,
    required this.onSelect,
    required this.onTransform,
    required this.onTransformEnd,
    required this.onDeselect,
    this.brushMode = false,
    this.onBrushStart,
    this.onBrushUpdate,
    this.onBrushEnd,
    this.viewScale = _defaultViewScale,
  });

  @override
  Widget build(BuildContext context) {
    final fullCanvasBrush = brushMode &&
        elements.any(
              (e) =>
          e.id == selectedElementId && e.type == EditorElementType.brush,
        );

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.white),
        ),

        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDeselect,
          ),
        ),

        for (final element in elements)
          if (element.visible)
            if (element.type == EditorElementType.brush)
              Positioned.fill(
                key: ValueKey(element.id),
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _StrokesPainter(element),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                key: ValueKey(element.id),
                child: _TransformableElement(
                  element: element,
                  selected: selectedElementId == element.id,
                  canvasWidth: canvasWidth,
                  canvasHeight: canvasHeight,
                  onTap: () => onSelect(element.id),
                  onTransform: onTransform,
                  onTransformEnd: onTransformEnd,
                  viewScale: viewScale,
                  brushMode: brushMode,
                  onBrushStart: onBrushStart,
                  onBrushUpdate: onBrushUpdate,
                  onBrushEnd: onBrushEnd,
                ),
              ),

        if (fullCanvasBrush)
          Positioned.fill(
            child: _BrushOverlay(
              onStart: onBrushStart,
              onUpdate: onBrushUpdate,
              onEnd: onBrushEnd,
            ),
          ),

        if (elements.isEmpty && !brushMode)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'Додай фото або текст',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrushOverlay extends StatefulWidget {
  final ValueChanged<Offset>? onStart;
  final ValueChanged<Offset>? onUpdate;
  final VoidCallback? onEnd;

  const _BrushOverlay({
    this.onStart,
    this.onUpdate,
    this.onEnd,
  });

  @override
  State<_BrushOverlay> createState() => _BrushOverlayState();
}

class _BrushOverlayState extends State<_BrushOverlay> {
  int? _pointer;

  void _finish(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        widget.onStart?.call(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer != _pointer) return;
        widget.onUpdate?.call(e.localPosition);
      },
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: const SizedBox.expand(),
    );
  }
}

class _TransformableElement extends StatefulWidget {
  final EditorElement element;
  final bool selected;
  final double canvasWidth;
  final double canvasHeight;
  final VoidCallback onTap;
  final void Function(
      String id,
      Offset position,
      double scale,
      double rotation,
      ) onTransform;
  final VoidCallback onTransformEnd;

  final double Function() viewScale;

  final bool brushMode;
  final ValueChanged<Offset>? onBrushStart;
  final ValueChanged<Offset>? onBrushUpdate;
  final VoidCallback? onBrushEnd;

  const _TransformableElement({
    required this.element,
    required this.selected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onTap,
    required this.onTransform,
    required this.onTransformEnd,
    required this.viewScale,
    this.brushMode = false,
    this.onBrushStart,
    this.onBrushUpdate,
    this.onBrushEnd,
  });

  @override
  State<_TransformableElement> createState() => _TransformableElementState();
}

class _TransformableElementState extends State<_TransformableElement> {
  Offset _startPosition = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  double _startScale = 1;
  double _startRotation = 0;

  @override
  Widget build(BuildContext context) {
    final element = widget.element;

    Widget content;

    switch (element.type) {
      case EditorElementType.image:
        content = _buildImage(element);
        break;
      case EditorElementType.text:
        content = _buildText(element);
        break;
      case EditorElementType.brush:
        content = const SizedBox.shrink();
        break;
    }

    return Center(
      child: Transform.translate(
        offset: element.position,
        child: Transform.rotate(
          angle: element.rotation,
          child: Transform.scale(
            scale: element.scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onScaleStart: widget.brushMode ? null : _handleScaleStart,
              onScaleUpdate: widget.brushMode ? null : _handleScaleUpdate,
              onScaleEnd: widget.brushMode ? null : _handleScaleEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRect(
                    child: Stack(
                      children: [
                        content,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _StrokesPainter(element),
                              ),
                            ),
                          ),
                        ),
                        if (widget.brushMode && widget.selected)
                          Positioned.fill(
                            child: _BrushOverlay(
                              onStart: widget.onBrushStart,
                              onUpdate: widget.onBrushUpdate,
                              onEnd: widget.onBrushEnd,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.selected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    widget.onTap();

    _startPosition = widget.element.position;
    _startScale = widget.element.scale;
    _startRotation = widget.element.rotation;
    _startFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final zoom = widget.viewScale();
    final delta = (details.focalPoint - _startFocalPoint) / zoom;

    final position = Offset(
      (_startPosition.dx + delta.dx)
          .clamp(-widget.canvasWidth / 2, widget.canvasWidth / 2)
          .toDouble(),
      (_startPosition.dy + delta.dy)
          .clamp(-widget.canvasHeight / 2, widget.canvasHeight / 2)
          .toDouble(),
    );

    final scale = (_startScale * details.scale).clamp(0.15, 8.0).toDouble();

    final rotation = _startRotation + details.rotation;

    widget.onTransform(
      widget.element.id,
      position,
      scale,
      rotation,
    );
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    widget.onTransformEnd();
  }

  Widget _buildImage(EditorElement element) {
    if (element.image == null) {
      return const SizedBox(width: 200, height: 200);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 320,
        maxHeight: 320,
      ),
      child: Image.file(
        element.image!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox(
          width: 200,
          height: 200,
          child: Icon(Icons.broken_image_outlined, size: 48),
        ),
      ),
    );
  }

  Widget _buildText(EditorElement element) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        element.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: element.textColor,
          fontSize: element.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
class _StrokesPainter extends CustomPainter {
  final EditorElement element;

  _StrokesPainter(this.element) : super(repaint: element.revision);

  @override
  void paint(Canvas canvas, Size size) {
    if (element.strokes.isEmpty) return;
    final hasEraser = element.strokes.any((s) => s.erase);
    if (hasEraser) {
      canvas.saveLayer(Offset.zero & size, Paint());
    }

    for (final stroke in element.strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawPath(
          stroke.path,
          paint..style = PaintingStyle.stroke,
        );
      }
    }

    if (hasEraser) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return oldDelegate.element != element;
  }
}