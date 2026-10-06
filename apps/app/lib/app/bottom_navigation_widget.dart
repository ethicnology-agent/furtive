import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_event.dart';
import 'package:furtive/features/activities/pages/activities_list_page.dart';
import 'package:furtive/features/activities/pages/activity_detail_page.dart';
import 'package:furtive/features/logs/logs_page.dart';
import 'package:furtive/features/map/pages/map_page.dart';
import 'package:furtive/features/permissions/pages/permissions_page.dart';
import 'package:furtive/features/preferences/page.dart';
import 'package:furtive/features/settings/settings_page.dart';
import 'package:furtive/features/share/live_share_control.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:map_view/map_view.dart';

class BottomNavigationWidget extends StatefulWidget {
  const BottomNavigationWidget({super.key, this.mapView});

  /// Rendering port handed to the map, for mounting this shell without a
  /// native map. The same seam [MapPage] already exposes, and for the same
  /// reason: the orchestration this widget performs when a recording ends is
  /// otherwise only reachable by running the application.
  final MapView? mapView;

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  late final PageController _pageController;
  late final ValueNotifier<int> _selectedTab;
  late final List<Widget> _pages;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedTab = ValueNotifier(0);
    _pages = [
      MapPage(
        mapView: widget.mapView,
        selectedTab: _selectedTab,
        // The map has room for the control; the share journey owns it.
        shareControlBuilder: LiveShareControl.maybe,
        // Orchestration across journeys, which is what a shell is for: the
        // activity list refreshes because a recording landed in it, and the
        // finished recording opens if the user was watching it happen.
        onRecordingCeased: (ceased, {required mapWasVisible}) {
          if (!mounted) return;
          context.read<ActivitiesBloc>().add(const FetchActivities());
          if (mapWasVisible) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityDetailPage(activity: ceased),
              ),
            );
          }
        },
      ),
      const ActivitiesListPage(),
      SettingsPage(
        // The menu names its destinations; reaching them is the shell's.
        onOpenPermissions: () => _push(
          (context) => PermissionsPage(onContinue: () async => _pop(context)),
        ),
        onOpenPreferences: (() => _push((_) => const PreferencesPage())),
        onOpenLogs: () => _push((_) => const LogsPage()),
      ),
    ];
  }

  void _push(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  void _pop(BuildContext context) => Navigator.of(context).pop();

  @override
  void dispose() {
    _pageController.dispose();
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          _selectedTab.value = index;
          setState(() => _currentIndex = index);
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _selectedTab.value = index;
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map_rounded),
            label: AppLocalizations.of(context).navMap,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt_outlined),
            activeIcon: const Icon(Icons.list_alt_rounded),
            label: AppLocalizations.of(context).navActivities,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings_rounded),
            label: AppLocalizations.of(context).navSettings,
          ),
        ],
      ),
    );
  }
}
