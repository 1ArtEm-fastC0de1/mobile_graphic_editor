import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../models/editor_element.dart';
import '../../models/project.dart';
import '../../services/project_service.dart';
import '../../services/project_storage.dart';
import 'crop_screen.dart';
import 'editor_canvas.dart';
import 'editor_toolbar.dart';
import 'layer_panel.dart';

class EditorScreen extends StatefulWidget {
  final Project project;

  const EditorScreen({
    super.key,
    required this.project,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  static const double _minZoom = 0.3;
  static const double _maxZoom = 10;

  final ImagePicker _imagePicker = ImagePicker();
  final ProjectService _projectService = ProjectService();
  final ProjectStorage _storage = ProjectStorage();
  final GlobalKey _canvasKey = GlobalKey();
  final TransformationController _viewController =
  TransformationController();

  late Project _project;

  final List<EditorElement> _elements = [];
  final List<List<EditorElement>> _undoStack = [];
  final List<List<EditorElement>> _redoStack = [];

  String? _selectedElementId;
  int _selectedTool = EditorToolbar.moveTool;

  bool _loading = true;
  bool _canSave = true;
  bool _dirty = false;
  bool _exiting = false;
  Timer? _autosaveTimer;
  Future<void> _saveChain = Future<void>.value();

  Size _viewportSize = Size.zero;

  bool _isTransforming = false;
  bool _exporting = false;

  Color _brushColor = Colors.black;
  double _brushWidth = 5;
  BrushStroke? _currentStroke;
  EditorElement? _currentLayer;

  EditorElement? get _selectedElement {
    for (final e in _elements) {
      if (e.id == _selectedElementId) return e;
    }
    return null;
  }

  bool get _drawTool =>
      _selectedTool == EditorToolbar.brushTool ||
          _selectedTool == EditorToolbar.eraserTool;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    WidgetsBinding.instance.addObserver(this);
    _loadProject();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    if (_dirty && !_loading) {
      _persist();
    }

    _viewController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_dirty) _persist();
    }
  }

  Future<void> _loadProject() async {
    final id = _project.id;

    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final loaded = await _storage.load(id);

      if (!mounted) return;

      setState(() {
        _elements
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _canSave = false;
      setState(() => _loading = false);

      _showMessage(
        'Не вдалося завантажити проєкт: $e',
        isError: true,
      );
    }
  }

  void _markDirty() {
    _dirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(seconds: 2),
          () => _persist(),
    );
  }

  Future<void> _persist({bool withThumbnail = false}) {
    _saveChain = _saveChain.then((_) => _persistNow(withThumbnail));
    return _saveChain;
  }

  Future<void> _persistNow(bool withThumbnail) async {
    final id = _project.id;
    if (id == null || !_canSave) return;

    _autosaveTimer?.cancel();
    _dirty = false;

    try {
      Uint8List? thumbnail;
      if (withThumbnail) {
        thumbnail = await _captureThumbnail();
      }

      final thumbnailPath = await _storage.save(
        projectId: id,
        elements: _elements,
        thumbnailPng: thumbnail,
      );

      final updated = Project(
        id: _project.id,
        name: _project.name,
        width: _project.width,
        height: _project.height,
        thumbnailPath: thumbnailPath ?? _project.thumbnailPath,
        createdAt: _project.createdAt,
        updatedAt: DateTime.now(),
      );

      await _projectService.updateProject(updated);
      _project = updated;
    } catch (_) {
      _dirty = true;
    }
  }

  Future<Uint8List?> _captureThumbnail() async {
    final boundary = _canvasKey.currentContext?.findRenderObject()
    as RenderRepaintBoundary?;

    if (boundary == null) return null;

    final longest = math.max(boundary.size.width, boundary.size.height);
    if (longest <= 0) return null;

    final image = await boundary.toImage(pixelRatio: 480 / longest);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return data?.buffer.asUint8List();
  }

  Future<void> _saveAndExit() async {
    if (_exiting) return;
    _exiting = true;

    if (_dirty) {
      setState(() => _selectedElementId = null);
      await WidgetsBinding.instance.endOfFrame;
      await _persist(withThumbnail: true);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveAndExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: _buildAppBar(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Expanded(child: _buildEditorArea()),
            if (_selectedTool == EditorToolbar.handTool)
              _buildViewControls(),
            if (_drawTool) _buildBrushControls(),
            LayerPanel(
              elements: _elements,
              selectedElementId: _selectedElementId,
              onSelect: _selectElement,
              onDelete: _deleteElement,
              onToggleVisibility: _toggleVisibility,
              onReorder: _reorderLayers,
              onMoveUp: () => _moveSelectedLayer(1),
              onMoveDown: () => _moveSelectedLayer(-1),
            ),
            EditorToolbar(
              selectedTool: _selectedTool,
              onToolSelected: _handleToolSelected,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF181818),
      foregroundColor: Colors.white,
      leading: IconButton(
        onPressed: _saveAndExit,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.project.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${widget.project.width} × ${widget.project.height}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white54,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Скасувати',
          onPressed: _undoStack.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: 'Повторити',
          onPressed: _redoStack.isEmpty ? null : _redo,
          icon: const Icon(Icons.redo_rounded),
        ),
        IconButton(
          tooltip: 'Зберегти в галерею',
          onPressed: _exporting ? null : _exportPng,
          icon: _exporting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.save_alt_rounded),
        ),
        IconButton(
          tooltip: 'Інші дії',
          onPressed: _showMoreMenu,
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }

  Widget _buildEditorArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;

        final availableWidth =
        (constraints.maxWidth - 32).clamp(1.0, double.infinity);
        final availableHeight =
        (constraints.maxHeight - 32).clamp(1.0, double.infinity);

        final ratio = widget.project.width / widget.project.height;

        double canvasWidth = availableWidth;
        double canvasHeight = canvasWidth / ratio;

        if (canvasHeight > availableHeight) {
          canvasHeight = availableHeight;
          canvasWidth = canvasHeight * ratio;
        }

        final handMode = _selectedTool == EditorToolbar.handTool;

        final canvas = Container(
          width: canvasWidth,
          height: canvasHeight,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: RepaintBoundary(
            key: _canvasKey,
            child: EditorCanvas(
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              elements: _elements,
              selectedElementId: _selectedElementId,
              onSelect: _selectElement,
              onTransform: _transformElement,
              onTransformEnd: _endTransform,
              onDeselect: _deselect,
              brushMode: _drawTool,
              onBrushStart: _startBrush,
              onBrushUpdate: _updateBrush,
              onBrushEnd: _endBrush,
              viewScale: _currentZoom,
            ),
          ),
        );
        return InteractiveViewer(
          transformationController: _viewController,
          minScale: _minZoom,
          maxScale: _maxZoom,
          boundaryMargin: const EdgeInsets.all(400),
          panEnabled: handMode,
          scaleEnabled: handMode,
          child: IgnorePointer(
            ignoring: handMode,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(child: canvas),
            ),
          ),
        );
      },
    );
  }

  double _currentZoom() => _viewController.value.getMaxScaleOnAxis();

  void _zoomBy(double factor) {
    final current = _currentZoom();
    final target = (current * factor).clamp(_minZoom, _maxZoom).toDouble();
    final f = target / current;

    final cx = _viewportSize.width / 2;
    final cy = _viewportSize.height / 2;

    final change = Matrix4.translationValues(cx, cy, 0) *
        Matrix4.diagonal3Values(f, f, 1) *
        Matrix4.translationValues(-cx, -cy, 0);

    _viewController.value = change * _viewController.value;
  }

  void _fitView() {
    _viewController.value = Matrix4.identity();
  }

  Widget _buildViewControls() {
    return ListenableBuilder(
      listenable: _viewController,
      builder: (context, _) {
        final percent = (_currentZoom() * 100).round();

        return Container(
          color: const Color(0xFF202020),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Два пальці — масштаб, один — рух полотна',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              IconButton(
                tooltip: 'Зменшити',
                visualDensity: VisualDensity.compact,
                onPressed: () => _zoomBy(1 / 1.25),
                icon: const Icon(Icons.remove_rounded),
              ),
              IconButton(
                tooltip: 'Збільшити',
                visualDensity: VisualDensity.compact,
                onPressed: () => _zoomBy(1.25),
                icon: const Icon(Icons.add_rounded),
              ),
              TextButton(
                onPressed: _fitView,
                child: const Text('Вмістити'),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildBrushControls() {
    final isEraser = _selectedTool == EditorToolbar.eraserTool;
    final hasLayer = _selectedElement != null;

    final hint = !hasLayer
        ? 'Вибери шар у панелі шарів'
        : isEraser
        ? 'Гумка стирає малюнок на вибраному шарі'
        : 'Малюєш на вибраному шарі (тільки в його межах)';

    return Container(
      color: const Color(0xFF202020),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    color: hasLayer ? Colors.white54 : Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isEraser)
                TextButton.icon(
                  onPressed: _createDrawingLayer,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Новий шар'),
                ),
            ],
          ),
          Row(
            children: [
              if (!isEraser)
                for (final color in [
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.white,
                ])
                  GestureDetector(
                    onTap: () => setState(() => _brushColor = color),
                    child: Container(
                      width: 23,
                      height: 23,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _brushColor == color
                              ? AppTheme.primary
                              : Colors.white24,
                          width: _brushColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(width: 4),
              const Text(
                'Розмір',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _brushWidth,
                  min: 1,
                  max: 30,
                  onChanged: (value) {
                    setState(() => _brushWidth = value);
                  },
                ),
              ),
              Text(
                _brushWidth.round().toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleToolSelected(int index) {
    switch (index) {
      case EditorToolbar.moveTool:
      case EditorToolbar.handTool:
      case EditorToolbar.brushTool:
      case EditorToolbar.eraserTool:
        setState(() => _selectedTool = index);
        break;
      case EditorToolbar.imageTool:
        _pickImage();
        break;
      case EditorToolbar.textTool:
        _addText();
        break;
      case EditorToolbar.cropTool:
        _cropSelectedImage();
        break;
      case EditorToolbar.shapeTool:
        _showMessage('Інструмент фігур буде додано окремо.');
        break;
    }
  }

  void _selectElement(String id) {
    setState(() => _selectedElementId = id);
  }

  void _deselect() {
    if (_selectedElementId == null) return;
    setState(() => _selectedElementId = null);
  }

  void _transformElement(
      String id,
      Offset position,
      double scale,
      double rotation,
      ) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    if (!_isTransforming) {
      _isTransforming = true;
      _saveHistory();
    }

    setState(() {
      final element = _elements[index];
      element.position = position;
      element.scale = scale;
      element.rotation = rotation;
      _selectedElementId = id;
    });
  }

  void _endTransform() {
    _isTransforming = false;
    _markDirty();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null || !mounted) return;

      _saveHistory();

      final element = EditorElement(
        id: _generateId(),
        type: EditorElementType.image,
        image: File(picked.path),
      );

      setState(() {
        _elements.add(element);
        _selectedElementId = element.id;
        _selectedTool = EditorToolbar.moveTool;
      });
    } catch (_) {
      _showMessage(
        'Не вдалося відкрити зображення.',
        isError: true,
      );
    }
  }

  Future<void> _cropSelectedImage() async {
    final element = _selectedElement;

    if (element == null ||
        element.type != EditorElementType.image ||
        element.image == null) {
      _showMessage('Спочатку виділи фото, яке треба обрізати.');
      return;
    }

    final result = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CropScreen(imageFile: element.image!),
      ),
    );

    if (!mounted || result == null) return;
    _saveHistory();

    setState(() {
      element.image = result;
    });
  }

  Future<void> _addText() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _TextInputDialog(),
    );

    if (!mounted || text == null || text.trim().isEmpty) return;

    _saveHistory();

    final element = EditorElement(
      id: _generateId(),
      type: EditorElementType.text,
      text: text.trim(),
    );

    setState(() {
      _elements.add(element);
      _selectedElementId = element.id;
      _selectedTool = EditorToolbar.moveTool;
    });
  }

  void _createDrawingLayer() {
    _saveHistory();

    final layer = EditorElement(
      id: _generateId(),
      type: EditorElementType.brush,
    );

    setState(() {
      _elements.add(layer);
      _selectedElementId = layer.id;
    });
  }

  void _startBrush(Offset point) {
    final layer = _selectedElement;

    if (layer == null) {
      _showMessage('Спочатку вибери шар (фото, текст або шар малювання).');
      return;
    }

    if (!layer.visible) {
      _showMessage('Шар приховано.');
      return;
    }

    _saveHistory();

    final width = layer.type == EditorElementType.brush
        ? _brushWidth
        : _brushWidth / layer.scale;

    final stroke = BrushStroke(
      color: _brushColor,
      width: width,
      erase: _selectedTool == EditorToolbar.eraserTool,
    )..add(point);

    layer.strokes.add(stroke);
    _currentStroke = stroke;
    _currentLayer = layer;

    layer.notifyChanged();
    setState(() {});
  }

  void _updateBrush(Offset point) {
    final stroke = _currentStroke;
    final layer = _currentLayer;
    if (stroke == null || layer == null) return;

    stroke.add(point);
    layer.notifyChanged();
  }

  void _endBrush() {
    if (_currentStroke == null) return;

    _currentStroke!.finish();
    _currentLayer?.notifyChanged();
    _currentStroke = null;
    _currentLayer = null;

    _markDirty();
  }

  void _deleteElement(String id) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _saveHistory();

    setState(() {
      _elements.removeAt(index);
      if (_selectedElementId == id) {
        _selectedElementId = null;
      }
    });
  }

  void _toggleVisibility(String id) {
    final index = _elements.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _saveHistory();

    setState(() {
      _elements[index].visible = !_elements[index].visible;
    });
  }

  void _reorderLayers(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    _saveHistory();

    final display = _elements.reversed.toList();
    final item = display.removeAt(oldIndex);
    display.insert(newIndex, item);

    setState(() {
      _elements
        ..clear()
        ..addAll(display.reversed);
    });
  }
  void _moveSelectedLayer(int delta) {
    final index = _elements.indexWhere((e) => e.id == _selectedElementId);
    if (index == -1) return;

    final target = index + delta;
    if (target < 0 || target >= _elements.length) return;

    _saveHistory();

    setState(() {
      final item = _elements.removeAt(index);
      _elements.insert(target, item);
    });
  }

  void _saveHistory() {
    _undoStack.add(_cloneElements(_elements));
    _redoStack.clear();

    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _markDirty();
  }

  void _restore(List<EditorElement> snapshot) {
    _elements
      ..clear()
      ..addAll(snapshot);

    if (!_elements.any((e) => e.id == _selectedElementId)) {
      _selectedElementId = null;
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    _isTransforming = false;
    _redoStack.add(_cloneElements(_elements));

    final previous = _undoStack.removeLast();

    setState(() => _restore(previous));
    _markDirty();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    _isTransforming = false;
    _undoStack.add(_cloneElements(_elements));

    final next = _redoStack.removeLast();

    setState(() => _restore(next));
    _markDirty();
  }

  List<EditorElement> _cloneElements(List<EditorElement> source) {
    return source.map((e) => e.copy()).toList();
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _selectedElementId = null;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _canvasKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Canvas is not ready');
      }
      final pixelRatio = widget.project.width / boundary.size.width;

      final ui.Image image = await boundary.toImage(
        pixelRatio: pixelRatio,
      );

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      image.dispose();

      if (byteData == null) {
        throw Exception('PNG encoding failed');
      }

      final bytes = byteData.buffer.asUint8List();

      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();

      if (!hasAccess) {
        _showMessage(
          'Немає дозволу на збереження в галерею.',
          isError: true,
        );
        return;
      }

      await Gal.putImageBytes(bytes);

      _showMessage('Збережено в галерею');
    } on GalException catch (e) {
      _showMessage(
        'Не вдалося зберегти в галерею: ${e.type.message}',
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Не вдалося експортувати PNG: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF181818),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Очистити полотно',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _clearCanvas();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.save_alt_rounded,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Зберегти в галерею',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _exportPng();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearCanvas() async {
    if (_elements.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Очистити полотно?'),
        content: const Text(
          'Усі додані елементи будуть видалені.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Очистити'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    _saveHistory();

    setState(() {
      _elements.clear();
      _selectedElementId = null;
      _currentStroke = null;
      _currentLayer = null;
      _isTransforming = false;
    });
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null,
        ),
      );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog();

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Додати текст'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Введіть текст',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Додати'),
        ),
      ],
    );
  }
}