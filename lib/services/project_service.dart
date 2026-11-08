import '../database/database.dart';
import '../models/editor_layer.dart';
import '../models/project.dart';

class ProjectService {
  final AppDatabase _database = AppDatabase.instance;
  Future<int> createProject(Project project) async {
    final db = await _database.database;

    return db.insert(
      'projects',
      project.toMap(),
    );
  }
  Future<List<Project>> getProjects() async {
    final db = await _database.database;

    final result = await db.query(
      'projects',
      orderBy: 'updated_at DESC',
    );

    return result
        .map((map) => Project.fromMap(map))
        .toList();
  }
  Future<void> updateProject(Project project) async {
    if (project.id == null) {
      throw Exception('Неможливо оновити проєкт без id');
    }
    final db = await _database.database;

    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }
  Future<void> deleteProject(int id) async {
    final db = await _database.database;

    await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveLayers(int projectId, List<EditorLayer> layers) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.delete(
        'layers',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );

      for (var i = 0; i < layers.length; i++) {
        await txn.insert(
          'layers',
          layers[i].toMap(projectId: projectId, zIndex: i),
        );
      }
    });
  }

  Future<List<EditorLayer>> getLayers(int projectId) async {
    final db = await _database.database;

    final result = await db.query(
      'layers',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'z_index ASC',
    );

    return result.map(EditorLayer.fromMap).toList();
  }
}