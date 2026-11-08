import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/editor_element.dart';

class ProjectStorage {
  final Map<String, String> _assetNames = {};

  Future<Directory> _projectDir(int projectId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'projects', '$projectId'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<String?> save({
    required int projectId,
    required List<EditorElement> elements,
    Uint8List? thumbnailPng,
  }) async {
    final dir = await _projectDir(projectId);

    final assets = Directory(p.join(dir.path, 'assets'));
    if (!await assets.exists()) {
      await assets.create(recursive: true);
    }

    final items = <Map<String, dynamic>>[];

    for (final element in elements) {
      final map = element.toJson();
      final image = element.image;

      if (image != null) {
        map['image'] = await _ensureAsset(assets, image);
      }

      items.add(map);
    }

    final tmp = File(p.join(dir.path, 'state.json.tmp'));
    await tmp.writeAsString(
      jsonEncode({'version': 1, 'elements': items}),
      flush: true,
    );
    await tmp.rename(p.join(dir.path, 'state.json'));

    if (thumbnailPng == null) return null;

    final thumb = File(
      p.join(
        dir.path,
        'thumb_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await thumb.writeAsBytes(thumbnailPng, flush: true);
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('thumb_') &&
          entity.path != thumb.path) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }

    return thumb.path;
  }

  Future<List<EditorElement>> load(int projectId) async {
    final dir = await _projectDir(projectId);
    final file = File(p.join(dir.path, 'state.json'));

    if (!await file.exists()) return [];

    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final items = (data['elements'] as List).cast<Map<String, dynamic>>();

      final used = <String>{};
      final result = <EditorElement>[];

      for (final map in items) {
        final name = map['image'] as String?;
        File? image;

        if (name != null) {
          image = File(p.join(dir.path, 'assets', name));
          used.add(name);
        }

        result.add(EditorElement.fromJson(map, image: image));
      }

      await _cleanupAssets(dir, used);

      return result;
    } catch (_) {
      try {
        await file.rename(p.join(dir.path, 'state.json.bak'));
      } catch (_) {}
      return [];
    }
  }

  Future<String?> duplicate({
    required int fromId,
    required int toId,
  }) async {
    final src = await _projectDir(fromId);
    final dst = await _projectDir(toId);

    await _copyDir(src, dst);

    String? thumbnail;
    await for (final entity in dst.list()) {
      if (entity is File && p.basename(entity.path).startsWith('thumb_')) {
        thumbnail = entity.path;
      }
    }

    return thumbnail;
  }

  Future<void> _copyDir(Directory from, Directory to) async {
    if (!await to.exists()) {
      await to.create(recursive: true);
    }

    await for (final entity in from.list()) {
      final target = p.join(to.path, p.basename(entity.path));

      if (entity is File) {
        await entity.copy(target);
      } else if (entity is Directory) {
        await _copyDir(entity, Directory(target));
      }
    }
  }

  Future<void> delete(int projectId) async {
    final dir = await _projectDir(projectId);

    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> _ensureAsset(Directory assets, File source) async {
    if (p.isWithin(assets.path, source.path)) {
      return p.basename(source.path);
    }

    final cached = _assetNames[source.path];
    if (cached != null &&
        await File(p.join(assets.path, cached)).exists()) {
      return cached;
    }

    var ext = p.extension(source.path);
    if (ext.isEmpty) ext = '.png';

    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await source.copy(p.join(assets.path, name));

    _assetNames[source.path] = name;
    return name;
  }

  Future<void> _cleanupAssets(Directory dir, Set<String> used) async {
    final assets = Directory(p.join(dir.path, 'assets'));
    if (!await assets.exists()) return;

    await for (final entity in assets.list()) {
      if (entity is File && !used.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}