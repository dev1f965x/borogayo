import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../text/josa.dart';
import '../theme.dart';
import 'project_screen.dart';
import 'settings_screen.dart';
import 'widgets/delete_action.dart';
import 'widgets/name_dialog.dart';
import 'widgets/toast.dart';

/// Home screen listing house-hunting projects.
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<ProjectSummary> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final summaries = await AppDatabase.instance.readProjectSummaries();
    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  /// Creates the project with the default criteria and opens it right away.
  Future<void> _create() async {
    final db = AppDatabase.instance;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: '새 목록',
        hint: '2026 봄 이사',
        confirmLabel: '만들기',
        check: (name) async =>
            await db.projectNameExists(name) ? '같은 이름의 목록이 있어요' : null,
      ),
    );
    if (name == null || !mounted) return;

    final id = await db.createProject(name);
    if (!mounted) return;
    HapticFeedback.lightImpact();

    final project = Project(id: id, name: name, createdAt: DateTime.now());
    final route = MaterialPageRoute<void>(
      builder: (_) => ProjectScreen(project: project),
    );
    final navigator = Navigator.of(context);
    showUndo(
      '‘$name’${objectJosa(name)} 만들었어요',
      onUndo: () async {
        if (route.isActive) navigator.removeRoute(route);
        await db.deleteProject(id);
        await _refresh();
      },
    );
    await navigator.push(route);
    await _refresh();
  }

  Future<void> _open(Project project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProjectScreen(project: project)),
    );
    await _refresh();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _refresh();
  }

  Future<void> _delete(Project project) async {
    final deletion = AppDatabase.instance.stageProjectDeletion(project.id);
    await _refresh();
    if (!mounted) return;

    showDeletionUndo(
      '‘${project.name}’${objectJosa(project.name)} 삭제했어요',
      deletion,
      onUndone: _refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  20,
                  AppSpacing.page,
                  120,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: ScreenTitle(
                          title: '보러가요',
                          subtitle: '오늘 본 집, 잊기 전에 점수로 남겨요',
                        ),
                      ),
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined),
                        color: palette.textMuted,
                        tooltip: '설정',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_summaries.isEmpty)
                    EmptyState(
                      icon: Icons.home_work_outlined,
                      title: '아직 목록이 없어요',
                      actionLabel: '새 목록 만들기',
                      onAction: _create,
                    )
                  else
                    for (final summary in _summaries) ...[
                      _ProjectCard(
                        summary: summary,
                        onTap: () => _open(summary.project),
                        onDelete: () => _delete(summary.project),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
      floatingActionButton: _loading || _summaries.isEmpty
          ? null
          : MainActionButton(
              icon: Icons.add,
              label: '새 목록',
              onPressed: _create,
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  final ProjectSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        summary.project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDate(summary.project.createdAt),
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '방 ${summary.roomCount} · 건물 ${summary.buildingCount}',
                  style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DeleteAction(onConfirm: onDelete),
        ],
      ),
    );
  }
}
