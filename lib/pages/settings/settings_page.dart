import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/cache/html_cache.dart';
import '../../services/download/download_service.dart';
import '../../state/library_scope.dart';
import '../../theme/tomo_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String? _status;

  Future<void> _run(Future<String> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final message = await job();
      if (!mounted) return;
      setState(() => _status = message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);

    return Scaffold(
      backgroundColor: tomoBackground,
      appBar: AppBar(
        backgroundColor: tomoBackground,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Data',
            style: TextStyle(
              color: tomoPink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.file_upload_outlined,
            title: 'Export backup',
            subtitle: 'Library, progress and update badges as JSON.',
            onTap: _busy
                ? null
                : () => _run(() async {
                      final file = await store.exportBackup();
                      await Clipboard.setData(ClipboardData(text: file.path));
                      return 'Backup saved and path copied:\n${file.path}';
                    }),
          ),
          _Tile(
            icon: Icons.file_download_outlined,
            title: 'Import backup',
            subtitle: 'Reads tomo_backup.json from Documents.',
            onTap: _busy
                ? null
                : () => _run(() async {
                      final docs = await getApplicationDocumentsDirectory();
                      final file = File(p.join(docs.path, 'tomo_backup.json'));
                      if (!await file.exists()) {
                        return 'No tomo_backup.json found in:\n${docs.path}';
                      }
                      final count = await store.importBackup(file);
                      return 'Imported $count manga.';
                    }),
          ),
          const SizedBox(height: 22),
          const Text(
            'Network',
            style: TextStyle(
              color: tomoPink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.sync_outlined,
            title: store.checkingUpdates
                ? 'Checking updates…'
                : 'Check library updates',
            subtitle: 'One series at a time, with delay to avoid 429.',
            onTap: _busy || store.checkingUpdates
                ? null
                : () => _run(() async {
                      await store.checkLibraryUpdates(force: true);
                      return store.updatedIds.isEmpty
                          ? 'No new chapters found.'
                          : '${store.updatedIds.length} series have new chapters.';
                    }),
          ),
          _Tile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear network cache',
            subtitle: 'Search, series and chapter lists.',
            onTap: _busy
                ? null
                : () => _run(() async {
                      await htmlCache.clear();
                      return 'Cache cleared.';
                    }),
          ),
          _Tile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete downloaded chapters',
            subtitle: 'Frees offline pages from the device.',
            onTap: _busy
                ? null
                : () => _run(() async {
                      await downloadService.clearAll();
                      return 'Downloads deleted.';
                    }),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(
              child: CircularProgressIndicator(color: tomoPink),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 18),
            Text(
              _status!,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tomoCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                Icon(icon, color: tomoPink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
