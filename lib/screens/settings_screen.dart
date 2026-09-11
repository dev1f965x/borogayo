import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../db/database.dart';
import '../media/media_store.dart';
import '../settings/theme_controller.dart';
import '../theme.dart';
import 'widgets/confirm_dialog.dart';

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

  Future<void> _confirmReset() async {
    final ok = await confirmDestructive(
      context,
      title: '모든 데이터 삭제',
      message: '만들어둔 목록과 건물·방, 매긴 점수와 사진·영상이 전부 지워집니다. 되돌릴 수 없어요.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteAllProjects();
    // Clearing the database leaves photo files behind; nothing references them now, so reclaim them.
    await MediaStore.cleanupOrphans(const {});
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('데이터를 모두 지웠어요.')));
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
          _SectionLabel('화면'),
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
          _SectionLabel('정보'),
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
          _SectionLabel('데이터'),
          const SizedBox(height: 10),
          AppCard(
            onTap: _confirmReset,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: palette.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '모든 데이터 삭제',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '기기에만 저장되므로 백업본은 없습니다.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
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
