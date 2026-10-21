import 'package:flutter/material.dart';
import 'package:furtive/features/settings/widgets/app_version_widget.dart';
import 'package:furtive/features/settings/widgets/support_developer_widget.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:ui_kit/ui_kit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onOpenPermissions,
    required this.onOpenPreferences,
    required this.onOpenLogs,
    required this.onOpenOfflineMaps,
    required this.onOpenChangelog,
  });

  /// What each row opens.
  ///
  /// This page is a menu: it names the destinations and knows what they are
  /// called. Reaching them is routing across three other journeys, and a
  /// menu that pushes them itself is a menu that imports them.
  final VoidCallback onOpenPermissions;
  final VoidCallback onOpenPreferences;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenOfflineMaps;
  final VoidCallback onOpenChangelog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(l10n.menuPermissions),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                  ),
                  onTap: onOpenPermissions,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: Text(l10n.menuOfflineMaps),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                  ),
                  onTap: onOpenOfflineMaps,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(l10n.menuPreferences),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                  ),
                  onTap: onOpenPreferences,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.menuLogs),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                  ),
                  onTap: onOpenLogs,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Until now the changelog was shown once, by the startup
                // gate, and never again: dismissing it was the only thing
                // standing between the user and never reading what changed.
                // The row reuses the page's own title rather than inventing
                // a label, so it needed no new string in 26 languages.
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(l10n.changelogTitle),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                  ),
                  onTap: onOpenChangelog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SupportDeveloperWidget(),
          const SizedBox(height: 12),
          const AppVersionWidget(),
        ],
      ),
    );
  }
}
