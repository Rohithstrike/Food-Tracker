import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/design_system/app_colors.dart';
import '../core/design_system/app_spacing.dart';
import '../data/food/food_provider.dart';
import '../data/food/food_repository.dart';
import '../data/food/sample_food_provider.dart';
import '../data/log/log_store.dart';
import '../domain/log/log_entry.dart';
import '../domain/nutrition/nutrition.dart';
import '../domain/nutrition/nutrition_engine.dart';
import '../features/log/day_log_controller.dart';
import '../features/log/default_meal.dart';
import '../features/log/log_feedback_banner.dart';
import '../features/search/food_search_page.dart';
import '../features/today/today_models.dart';
import '../features/today/today_page.dart';
import '../features/today/today_summary_adapter.dart';
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
/// Behaviour:
/// - Each tab keeps its own navigation stack and scroll position.
/// - Tapping the active tab returns that tab to its root page (iOS convention).
/// - Hidden tabs have animations paused.
/// - Today shows the day's logged food; + on a meal opens Search for it.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.controller, this.clock});

  /// Today's log. Created here (with in-memory storage) when not supplied.
  final DayLogController? controller;

  /// Injectable for tests. Defaults to the device's local time.
  final DateTime Function()? clock;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Duration _feedbackDuration = Duration(seconds: 4);

  /// Nutrients shown on Today; missing values for these are flagged.
  static const List<NutrientKind> _todayNutrients = <NutrientKind>[
    NutrientKind.energy,
    NutrientKind.protein,
    NutrientKind.carbohydrates,
    NutrientKind.fat,
    NutrientKind.fibre,
  ];

  AppTab _current = AppTab.today;

  /// The single source of food data for the app. Currently sample data
  /// only; licensed datasets are added as further providers.
  final FoodRepository _foods = FoodRepository(const <FoodProvider>[
    SampleFoodProvider(),
  ]);

  late final DayLogController _log;
  late final bool _ownsLog;
  LogEntry? _feedback;
  Timer? _feedbackTimer;

  final Map<AppTab, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>(),
  };

  @override
  void initState() {
    super.initState();
    final DayLogController? supplied = widget.controller;
    _ownsLog = supplied == null;
    _log =
        supplied ??
        DayLogController(store: InMemoryLogStore(), clock: widget.clock);
    unawaited(_log.load());
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    if (_ownsLog) {
      _log.dispose();
    }
    super.dispose();
  }

  void _select(AppTab tab) {
    if (tab == AppTab.today) {
      _log.checkDate();
    }
    if (tab == _current) {
      _navigatorKeys[tab]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _current = tab);
  }

  void _openSearchFor(MealSlot slot) {
    final NavigatorState? navigator =
        _navigatorKeys[AppTab.today]!.currentState;
    if (navigator == null) {
      return;
    }
    unawaited(
      navigator.push(
        CupertinoPageRoute<void>(
          builder: (BuildContext context) => FoodSearchPage(
            repository: _foods,
            controller: _log,
            clock: widget.clock,
            initialMealSlotId: slot.id,
            popOnAdd: true,
            onAdded: _showFeedback,
          ),
        ),
      ),
    );
  }

  void _showFeedback(LogEntry entry) {
    unawaited(_lightHaptic());
    _feedbackTimer?.cancel();
    setState(() => _feedback = entry);
    _feedbackTimer = Timer(_feedbackDuration, _hideFeedback);
  }

  void _hideFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    if (mounted && _feedback != null) {
      setState(() => _feedback = null);
    }
  }

  Future<void> _undoFeedback() async {
    final LogEntry? entry = _feedback;
    _hideFeedback();
    if (entry == null) {
      return;
    }
    try {
      await _log.undo(entry.id);
    } catch (_) {
      // Undo failed: the entry stays logged and remains visible on Today.
    }
  }

  static Future<void> _lightHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Haptics are optional (unavailable on web and in tests).
    }
  }

  String _feedbackMessage(LogEntry entry) {
    final String meal =
        mealSlotById(defaultMealSlots, entry.mealSlotId)?.name ?? 'your log';
    return 'Added ${entry.base.foodName} to $meal';
  }

  static bool _isIncomplete(NutritionTotals totals) => _todayNutrients.any(
    (NutrientKind kind) => totals.totalOf(kind).missingCount > 0,
  );

  Widget _todayPage() {
    return ListenableBuilder(
      listenable: _log,
      builder: (BuildContext context, Widget? child) {
        final TodayLogSummary today = summariseDayLog(
          _log.log,
          targets: DailyTargets.placeholder,
        );
        return TodayPage(
          summary: today.summary,
          hasIncompleteData: _isIncomplete(today.dayTotals),
          showDefaultTargetsNote: true,
          clock: widget.clock,
          onOpenSettings: () => _select(AppTab.settings),
          onAddFood: _openSearchFor,
        );
      },
    );
  }

  Widget _rootPage(AppTab tab) {
    return switch (tab) {
      AppTab.today => _todayPage(),
      AppTab.search => FoodSearchPage(
        repository: _foods,
        controller: _log,
        clock: widget.clock,
        onAdded: _showFeedback,
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
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final LogEntry? feedback = _feedback;

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
            bottom:
                FloatingTabBarMetrics.bottomOffset(safeBottom) +
                FloatingTabBarMetrics.height +
                AppSpacing.sm,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: FloatingTabBarMetrics.maxWidth,
                ),
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: feedback == null
                      ? const SizedBox.shrink()
                      : LogFeedbackBanner(
                          key: ValueKey<String>(feedback.id),
                          message: _feedbackMessage(feedback),
                          onUndo: () => unawaited(_undoFeedback()),
                        ),
                ),
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
