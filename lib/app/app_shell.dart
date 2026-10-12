import 'package:flutter/cupertino.dart';

import '../core/design_system/app_colors.dart';
import '../core/design_system/app_spacing.dart';
import '../features/today/today_page.dart';
import 'floating_tab_bar.dart';
import 'placeholder_page.dart';

/// The app's top-level destinations, in tab-bar order.
enum AppTab {
  today('Today', CupertinoIcons.sun_max, CupertinoIcons.sun_max_fill),
  search('Search', CupertinoIcons.search, CupertinoIcons.search),
  progress('Progress', CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill),
  settings('Settings', CupertinoIcons.gear, CupertinoIcons.gear_solid);

  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Four-tab navigation shell with a floating tab bar.
///
/// Pages fill the whole screen and scroll BEHIND the bar. The space the bar
/// occupies is passed to pages as bottom safe-area padding, so their last
/// content always clears it.
///
/// Behaviour (unchanged from Batch 1):
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

  void _select(AppTab tab) {
    if (tab == _current) {
      _navigatorKeys[tab]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _current = tab);
  }

  Widget _rootPage(AppTab tab) {
    return switch (tab) {
      AppTab.today => TodayPage(onOpenSettings: () => _select(AppTab.settings)),
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
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final occupied = FloatingTabBarMetrics.occupiedHeight(safeBottom);

    return ColoredBox(
      color: AppColors.background.resolveFrom(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(bottom: occupied),
                viewPadding: media.viewPadding.copyWith(bottom: occupied),
              ),
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
          Positioned(
            left: AppSpacing.pageMargin,
            right: AppSpacing.pageMargin,
            bottom: FloatingTabBarMetrics.bottomOffset(safeBottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: FloatingTabBarMetrics.maxWidth,
                ),
                child: FloatingTabBar(
                  currentIndex: _current.index,
                  onTap: (index) => _select(AppTab.values[index]),
                  items: [
                    for (final tab in AppTab.values)
                      FloatingTabItem(
                        label: tab.label,
                        icon: tab.icon,
                        activeIcon: tab.activeIcon,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
