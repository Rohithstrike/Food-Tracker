import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';

/// 05:00–11:59 morning, 12:00–16:59 afternoon, otherwise evening.
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  }
  if (hour >= 12 && hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

/// Time-aware greeting. Re-checks the clock every minute so the greeting
/// changes if the app stays open across a boundary.
class GreetingHeader extends StatefulWidget {
  const GreetingHeader({super.key, this.clock, this.onSettingsTap});

  /// Injectable for tests. Defaults to the device's local time.
  final DateTime Function()? clock;

  /// When provided, shows a Settings shortcut on the right.
  final VoidCallback? onSettingsTap;

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  Timer? _timer;
  late String _greeting;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _greeting = greetingFor(_now());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = greetingFor(_now());
      if (next != _greeting) {
        setState(() => _greeting = next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary.resolveFrom(context);
    final textSecondary = AppColors.textSecondary.resolveFrom(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  _greeting,
                  style: AppTypography.largeTitle.copyWith(color: textPrimary),
                  // Large titles grow with text size, but are capped so they
                  // don't dominate the screen at the largest settings.
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                "Let's make today count.",
                style: AppTypography.subheadline.copyWith(color: textSecondary),
              ),
            ],
          ),
        ),
        if (widget.onSettingsTap != null)
          CupertinoButton(
            key: const ValueKey('today-settings-shortcut'),
            padding: EdgeInsets.zero,
            onPressed: widget.onSettingsTap,
            child: Icon(
              CupertinoIcons.gear,
              size: AppIconSize.standard,
              color: textSecondary,
              semanticLabel: 'Settings',
            ),
          ),
      ],
    );
  }
}
