import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../db/database.dart';
import '../media/media_store.dart';
import '../settings/theme_controller.dart';
import '../theme.dart';
import 'criteria_screen.dart';
import 'widgets/toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  void _openDefaultCriteria() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const CriteriaScreen(title: '기본 평가 기준', store: DefaultCriteria()),
      ),
    );
  }

  /// Wiping everything is the one change that still asks first, then offers undo as well.
  Future<void> _deleteAll() async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모든 데이터를 삭제할까요?'),
        content: const Text('목록, 방, 사진이 모두 지워져요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.danger,
              minimumSize: const Size(88, 44),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = AppDatabase.instance;
    final deletion = await db.stageAllProjectsDeletion();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showDeletionUndo(
      '모든 데이터를 삭제했어요',
      deletion,
      afterCommit: () async =>
          MediaStore.cleanupOrphans(await db.readAllMediaPaths()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          8,
          AppSpacing.page,
          32,
        ),
        children: [
          const _SectionLabel('화면'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                for (final mode in ThemeMode.values) ...[
                  _ThemeOption(mode: mode),
                  if (mode != ThemeMode.values.last)
                    Divider(height: 16, color: palette.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('평가 기준'),
          const SizedBox(height: 10),
          AppCard(
            onTap: _openDefaultCriteria,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '기본 평가 기준',
                    style: TextStyle(fontSize: 15, color: palette.textBody),
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('정보'),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Text(
                  '버전',
                  style: TextStyle(fontSize: 15, color: palette.textBody),
                ),
                const Spacer(),
                Text(
                  _version.isEmpty ? '—' : _version,
                  style: TextStyle(fontSize: 14, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('데이터'),
          const SizedBox(height: 10),
          AppCard(
            onTap: _deleteAll,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: palette.danger),
                const SizedBox(width: 10),
                Text(
                  '모든 데이터 삭제',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = ThemeController.instance.mode == mode;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ThemeController.instance.setMode(mode);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                themeModeLabel(mode),
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textBody,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: palette.brand),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.palette.textMuted,
      ),
    );
  }
}
