import 'dart:io';

import 'package:flutter/material.dart';
import '../editor/editor_screen.dart';
import '../../app/theme.dart';
import '../../models/project.dart';
import '../../services/project_service.dart';
import '../../services/project_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProjectService _projectService = ProjectService();
  final ProjectStorage _storage = ProjectStorage();

  int _selectedNavigationIndex = 0;

  List<Project> _projects = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectService.getProjects();

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Помилка завантаження проєктів',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildCreateButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Графічний редактор',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showSearch,
          icon: const Icon(
            Icons.search_rounded,
            size: 23,
          ),
        ),
        IconButton(
          onPressed: _showSettings,
          icon: const Icon(
            Icons.settings_outlined,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Мої проєкти',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _projects.isEmpty
                  ? _buildEmptyState()
                  : _buildProjectsGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildProjectsGrid() {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),

        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),

        itemCount: _projects.length,

        itemBuilder: (context, index) {
          final project = _projects[index];

          return ProjectCard(
            project: project,

            onTap: () {
              _openProject(project);
            },

            onMenuTap: () {
              _showProjectMenu(project);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 34,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'У вас ще немає проєктів',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Створіть свій перший графічний проєкт',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Створити проєкт'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return FloatingActionButton.extended(
      onPressed: _createProject,

      icon: const Icon(
        Icons.add_rounded,
        size: 20,
      ),

      label: const Text(
        'Новий проєкт',
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedNavigationIndex,

      onDestinationSelected: (index) {
        setState(() {
          _selectedNavigationIndex = index;
        });
      },

      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder_rounded),
          label: 'Проєкти',
        ),

        NavigationDestination(
          icon: Icon(Icons.layers_outlined),
          selectedIcon: Icon(Icons.layers_rounded),
          label: 'Шаблони',
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Профіль',
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    final project = await showModalBottomSheet<Project>(
      context: context,

      backgroundColor: AppTheme.surface,

      showDragHandle: true,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),

      builder: (context) {
        return const CreateProjectSheet();
      },
    );

    if (project == null) return;

    try {
      await _projectService.createProject(project);

      await _loadProjects();

      if (!mounted) return;

      _showMessage(
        'Проєкт «${project.name}» створено',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Не вдалося створити проєкт',
        isError: true,
      );
    }
  }

  Future<void> _openProject(Project project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          project: project,
        ),
      ),
    );
    if (!mounted) return;
    await _loadProjects();
  }

  void _showProjectMenu(Project project) {
    showModalBottomSheet(
      context: context,

      backgroundColor: AppTheme.surface,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                  ),

                  title: const Text(
                    'Перейменувати',
                  ),

                  onTap: () {
                    Navigator.pop(context);

                    _renameProject(project);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.copy_outlined,
                  ),

                  title: const Text(
                    'Дублювати',
                  ),

                  onTap: () {
                    Navigator.pop(context);

                    _duplicateProject(project);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                  ),

                  iconColor: Colors.redAccent,

                  textColor: Colors.redAccent,

                  title: const Text(
                    'Видалити',
                  ),

                  onTap: () {
                    Navigator.pop(context);

                    _deleteProject(project);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameProject(Project project) async {
    final newName = await showDialog<String>(
      context: context,

      builder: (context) {
        return _RenameDialog(
          initialName: project.name,
        );
      },
    );

    if (newName == null || newName.isEmpty) {
      return;
    }

    try {
      final updatedProject = Project(
        id: project.id,
        name: newName,
        width: project.width,
        height: project.height,
        thumbnailPath: project.thumbnailPath,
        createdAt: project.createdAt,
        updatedAt: DateTime.now(),
      );

      await _projectService.updateProject(
        updatedProject,
      );

      await _loadProjects();

      if (!mounted) return;

      _showMessage(
        'Проєкт перейменовано',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Не вдалося перейменувати проєкт',
        isError: true,
      );
    }
  }

  Future<void> _duplicateProject(Project project) async {
    try {
      final duplicatedProject = Project(
        name: '${project.name} копія',
        width: project.width,
        height: project.height,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final newId = await _projectService.createProject(
        duplicatedProject,
      );

      if (project.id != null) {
        final thumbnailPath = await _storage.duplicate(
          fromId: project.id!,
          toId: newId,
        );

        if (thumbnailPath != null) {
          await _projectService.updateProject(
            Project(
              id: newId,
              name: duplicatedProject.name,
              width: duplicatedProject.width,
              height: duplicatedProject.height,
              thumbnailPath: thumbnailPath,
              createdAt: duplicatedProject.createdAt,
              updatedAt: duplicatedProject.updatedAt,
            ),
          );
        }
      }

      await _loadProjects();

      if (!mounted) return;

      _showMessage(
        'Проєкт продубльовано',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Не вдалося дублювати проєкт',
        isError: true,
      );
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Видалити проєкт?',
          ),

          content: Text(
            'Проєкт «${project.name}» буде видалено. '
                'Цю дію неможливо скасувати.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                'Скасувати',
              ),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),

              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child: const Text(
                'Видалити',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (project.id == null) return;

    try {
      await _projectService.deleteProject(
        project.id!,
      );

      try {
        await _storage.delete(project.id!);
      } catch (_) {}

      await _loadProjects();

      if (!mounted) return;

      _showMessage(
        'Проєкт «${project.name}» видалено',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Не вдалося видалити проєкт',
        isError: true,
      );
    }
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: ProjectSearchDelegate(
        projects: _projects,
        onProjectSelected: _openProject,
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,

      backgroundColor: AppTheme.surface,

      showDragHandle: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),

      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const ListTile(
                leading: Icon(
                  Icons.palette_outlined,
                ),

                title: Text(
                  'Тема оформлення',
                ),

                subtitle: Text(
                  'Темна',
                ),
              ),

              const ListTile(
                leading: Icon(
                  Icons.info_outline,
                ),

                title: Text(
                  'Про застосунок',
                ),

                subtitle: Text(
                  'Графічний редактор',
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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

          backgroundColor:
          isError ? Colors.redAccent : null,
        ),
      );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({
    required this.initialName,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
  TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) return;

    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Перейменувати проєкт',
      ),

      content: TextField(
        controller: _controller,

        autofocus: true,

        decoration: const InputDecoration(
          hintText: 'Назва проєкту',
        ),

        textInputAction: TextInputAction.done,

        onSubmitted: (_) => _submit(),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },

          child: const Text(
            'Скасувати',
          ),
        ),

        FilledButton(
          onPressed: _submit,

          child: const Text(
            'Зберегти',
          ),
        ),
      ],
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Project project;

  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const ProjectCard({
    super.key,

    required this.project,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: Container(
              width: double.infinity,

              decoration: BoxDecoration(
                color: AppTheme.surface,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: AppTheme.border,
                ),
              ),

              clipBehavior: Clip.antiAlias,

              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildThumbnail(),
                  ),

                  Positioned(
                    top: 6,
                    right: 6,

                    child: Material(
                      color: Colors.black.withValues(
                        alpha: 0.55,
                      ),

                      borderRadius:
                      BorderRadius.circular(10),

                      child: InkWell(
                        onTap: onMenuTap,

                        borderRadius:
                        BorderRadius.circular(10),

                        child: const Padding(
                          padding: EdgeInsets.all(5),

                          child: Icon(
                            Icons.more_vert_rounded,

                            size: 19,

                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            project.name,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: AppTheme.textPrimary,

              fontSize: 13,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            _formatDate(project.updatedAt),

            style: const TextStyle(
              color: AppTheme.textSecondary,

              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final path = project.thumbnailPath;

    if (path == null || path.isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_outlined,

          color: AppTheme.textSecondary,

          size: 32,
        ),
      );
    }

    final file = File(path);

    if (!file.existsSync()) {
      return const Center(
        child: Icon(
          Icons.image_outlined,

          color: AppTheme.textSecondary,

          size: 32,
        ),
      );
    }

    return Image.file(
      file,

      fit: BoxFit.cover,

      errorBuilder: (
          context,
          error,
          stackTrace,
          ) {
        return const Center(
          child: Icon(
            Icons.image_outlined,

            color: AppTheme.textSecondary,

            size: 32,
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Щойно';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} хв тому';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} год тому';
    }

    if (difference.inDays == 1) {
      return 'Вчора';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} дні тому';
    }

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}


class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({
    super.key,
  });

  @override
  State<CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState
    extends State<CreateProjectSheet> {
  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _widthController =
  TextEditingController(
    text: '1080',
  );

  final TextEditingController _heightController =
  TextEditingController(
    text: '1080',
  );

  int _selectedPreset = 0;

  final List<ProjectPreset> _presets = const [
    ProjectPreset(
      name: 'Instagram Post',
      width: 1080,
      height: 1080,
    ),

    ProjectPreset(
      name: 'Instagram Story',
      width: 1080,
      height: 1920,
    ),

    ProjectPreset(
      name: 'YouTube',
      width: 1280,
      height: 720,
    ),

    ProjectPreset(
      name: 'Власний',
      width: 1080,
      height: 1080,
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        32 + bottomInset,
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Text(
            'Новий проєкт',

            style: TextStyle(
              color: AppTheme.textPrimary,

              fontSize: 22,

              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Назва проєкту',

            style: TextStyle(
              color: AppTheme.textSecondary,

              fontSize: 13,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _nameController,

            textInputAction:
            TextInputAction.next,

            decoration: InputDecoration(
              hintText: 'Мій дизайн',

              filled: true,

              fillColor:
              AppTheme.surfaceLight,

              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),

                borderSide:
                BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Розмір полотна',

            style: TextStyle(
              color: AppTheme.textSecondary,

              fontSize: 13,
            ),
          ),

          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,

            physics:
            const NeverScrollableScrollPhysics(),

            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,

              crossAxisSpacing: 8,

              mainAxisSpacing: 8,

              childAspectRatio: 2.6,
            ),

            itemCount: _presets.length,

            itemBuilder: (
                context,
                index,
                ) {
              final preset =
              _presets[index];

              final selected =
                  _selectedPreset == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPreset =
                        index;

                    _widthController
                        .text =
                        preset.width
                            .toString();

                    _heightController
                        .text =
                        preset.height
                            .toString();
                  });
                },

                child: Container(
                  decoration:
                  BoxDecoration(
                    color: selected
                        ? AppTheme.primary
                        .withValues(
                      alpha: 0.15,
                    )
                        : AppTheme
                        .surfaceLight,

                    borderRadius:
                    BorderRadius
                        .circular(10),

                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : Colors.transparent,
                    ),
                  ),

                  child: Center(
                    child: Text(
                      preset.name,

                      textAlign:
                      TextAlign.center,

                      style: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme
                            .textPrimary,

                        fontSize: 12,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _buildSizeField(
                  label: 'Ширина',

                  controller:
                  _widthController,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildSizeField(
                  label: 'Висота',

                  controller:
                  _heightController,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,

            height: 52,

            child: FilledButton(
              onPressed: _create,

              style:
              FilledButton.styleFrom(
                backgroundColor:
                AppTheme.primary,

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),

              child: const Text(
                'Створити проєкт',

                style: TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _create() {
    final name =
    _nameController.text.trim();

    final width = int.tryParse(
      _widthController.text.trim(),
    ) ??
        1080;

    final height = int.tryParse(
      _heightController.text.trim(),
    ) ??
        1080;

    if (width <= 0 || height <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Вкажіть правильний розмір полотна',
          ),
        ),
      );

      return;
    }

    final project = Project(
      name: name.isEmpty
          ? 'Мій проєкт'
          : name,

      width: width,

      height: height,

      createdAt: DateTime.now(),

      updatedAt: DateTime.now(),
    );

    Navigator.pop(
      context,
      project,
    );
  }

  Widget _buildSizeField({
    required String label,

    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: const TextStyle(
            color:
            AppTheme.textSecondary,

            fontSize: 12,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,

          keyboardType:
          TextInputType.number,

          decoration:
          InputDecoration(
            suffixText: 'px',

            filled: true,

            fillColor:
            AppTheme.surfaceLight,

            border:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                10,
              ),

              borderSide:
              BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class ProjectPreset {
  final String name;

  final int width;

  final int height;

  const ProjectPreset({
    required this.name,

    required this.width,

    required this.height,
  });
}

class ProjectSearchDelegate
    extends SearchDelegate<Project?> {
  final List<Project> projects;

  final void Function(Project project)
  onProjectSelected;

  ProjectSearchDelegate({
    required this.projects,

    required this.onProjectSelected,
  });

  @override
  List<Widget>? buildActions(
      BuildContext context,
      ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },

          icon: const Icon(
            Icons.clear,
          ),
        ),
    ];
  }

  @override
  Widget? buildLeading(
      BuildContext context,
      ) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },

      icon: const Icon(
        Icons.arrow_back,
      ),
    );
  }

  @override
  Widget buildResults(
      BuildContext context,
      ) {
    return _buildResults();
  }

  @override
  Widget buildSuggestions(
      BuildContext context,
      ) {
    return _buildResults();
  }

  Widget _buildResults() {
    final searchQuery =
    query.trim().toLowerCase();

    final results = projects.where(
          (project) {
        return project.name
            .toLowerCase()
            .contains(searchQuery);
      },
    ).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Проєктів не знайдено',
          style: TextStyle(
            color:
            AppTheme.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,

      itemBuilder: (
          context,
          index,
          ) {
        final project =
        results[index];

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: AppTheme.surface,

              borderRadius:
              BorderRadius.circular(
                8,
              ),
            ),

            child: const Icon(
              Icons.image_outlined,
            ),
          ),

          title: Text(
            project.name,
          ),

          subtitle: Text(
            '${project.width} × ${project.height}',
          ),

          onTap: () {
            close(
              context,
              project,
            );

            onProjectSelected(
              project,
            );
          },
        );
      },
    );
  }
}