class Project {
  final int? id;
  final String name;
  final int width;
  final int height;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    this.id,
    required this.name,
    required this.width,
    required this.height,
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'width': width,
      'height': height,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}