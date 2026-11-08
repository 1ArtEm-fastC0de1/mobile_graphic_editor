import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;import 'package:flutter/gestures.dart';


import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;

  const CropScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _CropScreenState extends State<CropScreen> {
  static const double _minSize = 0.08;
  static const double _hitRadius = 36;
  static const double _padding = 16;
  static const Rect _full = Rect.fromLTRB(0, 0, 1, 1);

  ui.Image? _image;
  bool _failed = false;
  bool _saving = false;

  Rect _crop = _full;
  _DragMode _mode = _DragMode.none;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();

      if (!mounted) {
        frame.image.dispose();
        return;
      }

      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Rect _fitRect(Size area) {
    final image = _image!;
    final availW = math.max(1.0, area.width - _padding * 2);
    final availH = math.max(1.0, area.height - _padding * 2);

    final scale = math.min(availW / image.width, availH / image.height);
    final w = image.width * scale;
    final h = image.height * scale;

    return Rect.fromLTWH(
      (area.width - w) / 2,
      (area.height - h) / 2,
      w,
      h,
    );
  }

  Rect _toDisplay(Rect imageRect) {
    return Rect.fromLTRB(
      imageRect.left + _crop.left * imageRect.width,
      imageRect.top + _crop.top * imageRect.height,
      imageRect.left + _crop.right * imageRect.width,
      imageRect.top + _crop.bottom * imageRect.height,
    );
  }

  double _c(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  void _onPanStart(DragStartDetails d, Rect cropRect) {
    final p = d.localPosition;

    if ((p - cropRect.topLeft).distance < _hitRadius) {
      _mode = _DragMode.topLeft;
    } else if ((p - cropRect.topRight).distance < _hitRadius) {
      _mode = _DragMode.topRight;
    } else if ((p - cropRect.bottomLeft).distance < _hitRadius) {
      _mode = _DragMode.bottomLeft;
    } else if ((p - cropRect.bottomRight).distance < _hitRadius) {
      _mode = _DragMode.bottomRight;
    } else if (cropRect.contains(p)) {
      _mode = _DragMode.move;
    } else {
      _mode = _DragMode.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Rect imageRect) {
    if (_mode == _DragMode.none) return;

    final dx = d.delta.dx / imageRect.width;
    final dy = d.delta.dy / imageRect.height;
    final r = _crop;
    Rect next;

    switch (_mode) {
      case _DragMode.none:
        return;
      case _DragMode.move:
        final moved = r.shift(Offset(dx, dy));
        final fixX = moved.left < 0
            ? -moved.left
            : (moved.right > 1 ? 1 - moved.right : 0.0);
        final fixY = moved.top < 0
            ? -moved.top
            : (moved.bottom > 1 ? 1 - moved.bottom : 0.0);
        next = moved.shift(Offset(fixX, fixY));
        break;
      case _DragMode.topLeft:
        next = Rect.fromLTRB(
          _c(r.left + dx, 0, r.right - _minSize),
          _c(r.top + dy, 0, r.bottom - _minSize),
          r.right,
          r.bottom,
        );
        break;
      case _DragMode.topRight:
        next = Rect.fromLTRB(
          r.left,
          _c(r.top + dy, 0, r.bottom - _minSize),
          _c(r.right + dx, r.left + _minSize, 1),
          r.bottom,
        );
        break;
      case _DragMode.bottomLeft:
        next = Rect.fromLTRB(
          _c(r.left + dx, 0, r.right - _minSize),
          r.top,
          r.right,
          _c(r.bottom + dy, r.top + _minSize, 1),
        );
        break;
      case _DragMode.bottomRight:
        next = Rect.fromLTRB(
          r.left,
          r.top,
          _c(r.right + dx, r.left + _minSize, 1),
          _c(r.bottom + dy, r.top + _minSize, 1),
        );
        break;
    }

    setState(() => _crop = next);
  }

  Future<void> _apply() async {
    final image = _image;
    if (image == null || _saving) return;

    if (_crop == _full) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    try {
      final src = Rect.fromLTRB(
        _crop.left * image.width,
        _crop.top * image.height,
        _crop.right * image.width,
        _crop.bottom * image.height,
      );

      final w = src.width.round().clamp(1, image.width);
      final h = src.height.round().clamp(1, image.height);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      picture.dispose();

      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();

      if (data == null) throw Exception('PNG encoding failed');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
            'crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.pop(context, file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не вдалося обрізати: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        title: const Text('Обрізка'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: (_image == null || _saving) ? null : _apply,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Готово'),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: const Color(0xFF181818),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Тягни кути рамки або саму рамку',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _crop = _full),
                child: const Text('Скинути'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_failed) {
      return const Center(
        child: Text(
          'Не вдалося відкрити зображення',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageRect = _fitRect(constraints.biggest);
        final cropRect = _toDisplay(imageRect);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) => _onPanStart(d, cropRect),
          onPanUpdate: (d) => _onPanUpdate(d, imageRect),
          onPanEnd: (_) => _mode = _DragMode.none,
          onPanCancel: () => _mode = _DragMode.none,
          child: CustomPaint(
            size: constraints.biggest,
            painter: _CropPainter(
              image: image,
              imageRect: imageRect,
              crop: cropRect,
            ),
          ),
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final Rect crop;

  const _CropPainter({
    required this.image,
    required this.imageRect,
    required this.crop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(imageRect),
      Path()..addRect(crop),
    );
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.6));

    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const length = 20.0;

    for (final point in [
      crop.topLeft,
      crop.topRight,
      crop.bottomLeft,
      crop.bottomRight,
    ]) {
      final sx = point.dx == crop.left ? 1.0 : -1.0;
      final sy = point.dy == crop.top ? 1.0 : -1.0;
      canvas.drawLine(point, point + Offset(length * sx, 0), corner);
      canvas.drawLine(point, point + Offset(0, length * sy), corner);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) {
    return old.image != image || old.imageRect != imageRect || old.crop != crop;
  }
}