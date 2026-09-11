import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';
import 'settings_screen.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/delete_action.dart';
import 'widgets/entry_dialog.dart';

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

  /// Asks for the name in a dialog, then sets up criteria on the next screen.
  /// A single name field doesn't belong on the same page as a dozen criteria.
  Future<void> _openForm() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '새 목록',
        nameHint: '예: 2026 봄 이사',
        confirmLabel: '다음',
        nameCheck: (name) async =>
            await AppDatabase.instance.projectNameExists(name)
            ? '같은 이름의 목록이 이미 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProjectFormScreen(name: entry.name)),
    );
    await _refresh();
  }

  Future<void> _openProject(Project project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
    await _refresh();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _refresh();
  }

  /// Deleting a project removes everything in it, so it takes a confirmation on top of the double tap.
  Future<void> _confirmDelete(Project project) async {
    final ok = await confirmDestructive(
      context,
      title: '‘${project.name}’ 삭제',
      message: '이 목록의 건물과 방, 점수와 사진·영상이 모두 지워집니다.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteProject(project.id!);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
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
                          subtitle: '오늘 본 집, 잊기 전에 점수로 남겨요.',
                        ),
                      ),
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined),
                        color: context.palette.textMuted,
                        tooltip: '설정',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_summaries.isEmpty)
                    EmptyState(
                      icon: Icons.home_work_outlined,
                      title: '아직 만든 목록이 없어요',
                      description: '이사 한 번에 목록 하나.\n보러 갈 집을 여기에 모아둡니다.',
                      actionLabel: '첫 목록 만들기',
                      onAction: _openForm,
                    )
                  else
                    for (final summary in _summaries) ...[
                      _ProjectCard(
                        summary: summary,
                        onTap: () => _openProject(summary.project),
                        onDelete: () => _confirmDelete(summary.project),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
      floatingActionButton: _summaries.isEmpty && !_loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _openForm,
              backgroundColor: context.palette.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: const Text(
                '새 목록',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
                Text(
                  summary.project.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '건물 ${summary.buildingCount}곳 · 방 ${summary.roomCount}칸 · '
                  '${formatDate(summary.project.createdAt)}',
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
