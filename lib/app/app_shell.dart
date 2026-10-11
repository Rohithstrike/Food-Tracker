import 'package:flutter/cupertino.dart';

import '../core/design_system/app_colors.dart';
import '../features/today/today_page.dart';
import 'placeholder_page.dart';

/// The app's top-level destinations, in tab-bar order.
enum AppTab {
  today('Today', CupertinoIcons.sun_max, CupertinoIcons.sun_max_fill),
  search('Search', CupertinoIcons.search, CupertinoIcons.search),
  progress(
    'Progress',
    CupertinoIcons.chart_bar,
    CupertinoIcons.chart_bar_fill,
  ),
  settings('Settings', CupertinoIcons.gear, CupertinoIcons.gear_solid);

  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Four-tab navigation shell.
///
/// Built from CupertinoTabBar + CupertinoTabView + IndexedStack rather than
/// CupertinoTabScaffold, so a later milestone can float a translucent tab
/// bar over scrolling content by changing only this file.
///
/// Behaviour:
/// - Each tab keeps its own navigation stack and scroll position.
/// - Tapping the active tab returns that tab to its root page (iOS convention).
/// - Hidden tabs have animations paused.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _current = AppTab.today;

  final Map<AppTab, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>(),
  };

  void _onTabTapped(int index) {
    final tapped = AppTab.values[index];
    if (tapped == _current) {
      _navigatorKeys[tapped]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _current = tapped);
  }

  Widget _rootPage(AppTab tab) {
    return switch (tab) {
      AppTab.today => const TodayPage(),
      AppTab.search => const PlaceholderPage(
          title: 'Search',
          icon: CupertinoIcons.search,
          message: 'Food search arrives in a later milestone.',
        ),
      AppTab.progress => const PlaceholderPage(
          title: 'Progress',
          icon: CupertinoIcons.chart_bar,
          message: 'Progress tracking arrives in a later milestone.',
        ),
      AppTab.settings => const PlaceholderPage(
          title: 'Settings',
          icon: CupertinoIcons.gear,
          message: 'Settings arrive in a later milestone.',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.resolveFrom(context),
      child: Column(
        children: [
          Expanded(
            // The tab bar handles the bottom safe area itself, so page
            // content must not add it again.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: IndexedStack(
                index: _current.index,
                children: [
                  for (final tab in AppTab.values)
                    TickerMode(
                      enabled: tab == _current,
                      child: CupertinoTabView(
                        navigatorKey: _navigatorKeys[tab],
                        builder: (context) => _rootPage(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // iOS does not scale tab-bar labels with Dynamic Type; page
          // content still scales fully.
          MediaQuery.withNoTextScaling(
            child: CupertinoTabBar(
              currentIndex: _current.index,
              onTap: _onTabTapped,
              backgroundColor: AppColors.surface.resolveFrom(context),
              activeColor: AppColors.accent.resolveFrom(context),
              inactiveColor: AppColors.textSecondary.resolveFrom(context),
              border: Border(
                top: BorderSide(
                  color: AppColors.separator.resolveFrom(context),
                  width: 0, // Hairline.
                ),
              ),
              items: [
                for (final tab in AppTab.values)
                  BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    activeIcon: Icon(tab.activeIcon),
                    label: tab.label,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}