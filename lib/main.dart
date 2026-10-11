import 'package:flutter/cupertino.dart';

void main() {
  runApp(const IndianFoodTrackerApp());
}

/// Root of the application.
/// Uses CupertinoApp so the app follows iOS design conventions.
/// Brightness is not fixed, so it follows the system light/dark setting.
class IndianFoodTrackerApp extends StatelessWidget {
  const IndianFoodTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Indian Food Tracker',
      debugShowCheckedModeBanner: false,
      home: TodayShell(),
    );
  }
}

/// Temporary Today screen shell.
/// Contains no nutrition data — real features arrive in later milestones.
class TodayShell extends StatelessWidget {
  const TodayShell({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final secondaryColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Today'),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.square_list,
                      size: 48,
                      color: secondaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nothing logged yet',
                      style: textTheme.navTitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your meals for today will appear here.',
                      style: textTheme.textStyle.copyWith(
                        color: secondaryColor,
                      ),
                      textAlign: TextAlign.center,
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