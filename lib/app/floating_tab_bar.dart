import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../core/design_system/app_colors.dart';
import '../core/design_system/app_spacing.dart';
import '../core/design_system/app_typography.dart';

/// One destination in the [FloatingTabBar].
class FloatingTabItem {
  const FloatingTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Size, placement and material values for the floating tab bar.
abstract final class FloatingTabBarMetrics {
  /// Bar height. Tab labels do not scale with text size (iOS convention),
  /// so a fixed height is safe here.
  static const double height = AppSpacing.giant; // 64

  /// Keeps the bar a comfortable width on wide windows.
  static const double maxWidth = 440;

  /// Opacity of the glass fill. 0.92 keeps tab labels at or above 4.5:1
  /// even over the darkest/lightest content behind the bar (see tests).
  static const double glassOpacity = 0.92;

  /// Blur strength for content behind the bar.
  static const double blurSigma = 24;

  /// Gap between the bar and the bottom edge of the screen: just above the
  /// home indicator, or 16 pt up on devices without one.
  static double bottomOffset(double safeBottom) =>
      safeBottom > 0 ? safeBottom : AppSpacing.md;

  /// Total height reserved at the bottom of the screen. Pages receive this
  /// as bottom safe-area padding so their last content clears the bar.
  static double occupiedHeight(double safeBottom) =>
      bottomOffset(safeBottom) + height;
}

/// Fill colour for the bar: translucent glass, or fully solid.
Color floatingTabBarFill(BuildContext context, {required bool solid}) {
  final base = AppColors.surfaceElevated.resolveFrom(context);
  return solid
      ? base
      : base.withValues(alpha: FloatingTabBarMetrics.glassOpacity);
}

/// Floating, capsule-shaped tab bar with an Apple-inspired frosted surface.
///
/// This is a Flutter blur (BackdropFilter), not Apple's native Liquid Glass.
/// A solid fallback is used when the system requests higher contrast.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.forceSolid = false,
  });

  final List<FloatingTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Reserved for a future in-app "Reduce transparency" setting.
  final bool forceSolid;

  @override
  Widget build(BuildContext context) {
    // Flutter does not currently expose iOS "Reduce Transparency".
    // "Increase Contrast" (highContrast) is exposed, so it triggers the
    // solid fallback.
    final solid = forceSolid || MediaQuery.highContrastOf(context);
    final isLight = CupertinoTheme.brightnessOf(context) == Brightness.light;

    Widget surface = DecoratedBox(
      key: const ValueKey('floating-tab-bar-surface'),
      decoration: BoxDecoration(
        color: floatingTabBarFill(context, solid: solid),
        borderRadius: AppRadius.capsuleAll,
        border: Border.all(
          color: AppColors.separator.resolveFrom(context),
          width: 0, // Hairline.
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );

    if (!solid) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: FloatingTabBarMetrics.blurSigma,
          sigmaY: FloatingTabBarMetrics.blurSigma,
        ),
        child: surface,
      );
    }

    // iOS does not scale tab-bar labels with Dynamic Type.
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: FloatingTabBarMetrics.height,
        width: double.infinity,
        child: DecoratedBox(
          // Soft lift in light mode only; in dark mode the lighter surface
          // already communicates elevation.
          decoration: BoxDecoration(
            borderRadius: AppRadius.capsuleAll,
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.color.withValues(
                        alpha: 0.08,
                      ),
                      blurRadius: AppSpacing.xl,
                      offset: const Offset(0, AppSpacing.xs),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(borderRadius: AppRadius.capsuleAll, child: surface),
        ),
      ),
    );
  }
}

/// One tab: icon + label. Selection is shown by a filled icon, the accent
/// colour AND a heavier label, so colour is never the only cue.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.accent.resolveFrom(context)
        : AppColors.textSecondary.resolveFrom(context);

    return Semantics(
      key: ValueKey('tab-${item.label.toLowerCase()}'),
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: item.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: AppIconSize.standard,
                color: color,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
