// Search tab: instant, offline food search over the FoodRepository.
//
// Results show each food's state, energy per 100 g and a "Sample" label for
// development data. Tapping a result opens the food detail sheet.

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import '../../data/food/food_repository.dart';
import '../../domain/food/food.dart';
import 'food_detail_sheet.dart';
import 'food_labels.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key, required this.repository});

  final FoodRepository repository;

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _controller = TextEditingController();
  late final Future<void> _loading = widget.repository.load();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Food food) {
    showFoodDetailSheet(
      context,
      food: food,
      oilFood: food.id == defaultOilFoodId
          ? null
          : widget.repository.foodById(defaultOilFoodId),
    );
  }

  Widget _body(AsyncSnapshot<void> snapshot) {
    if (snapshot.hasError) {
      return const _Message(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Food data could not be loaded',
        message: 'Please close and reopen the app.',
      );
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const _Message(
        icon: CupertinoIcons.search,
        title: 'Loading foods\u2026',
        message: '',
      );
    }
    if (_query.trim().isEmpty) {
      return const _Message(
        icon: CupertinoIcons.search,
        title: searchHint,
        message: sampleDataNotice,
      );
    }
    final List<FoodSearchResult> results = widget.repository.search(_query);
    if (results.isEmpty) {
      return _Message(
        icon: CupertinoIcons.question_circle,
        title: 'No foods match "${_query.trim()}"',
        message: 'Check the spelling or try another name.',
      );
    }
    return _ResultList(
      foods: <Food>[for (final FoodSearchResult r in results) r.food],
      onTap: _open,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: FutureBuilder<void>(
        future: _loading,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              const CupertinoSliverNavigationBar(largeTitle: Text('Search')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin,
                    AppSpacing.xs,
                    AppSpacing.pageMargin,
                    AppSpacing.md,
                  ),
                  child: CupertinoSearchTextField(
                    key: const ValueKey<String>('food-search-field'),
                    controller: _controller,
                    placeholder: 'Search foods',
                    onChanged: (String value) => setState(() {
                      _query = value;
                    }),
                  ),
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin,
                    0,
                    AppSpacing.pageMargin,
                    AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(child: _body(snapshot)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.foods, required this.onTap});

  final List<Food> foods;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) {
    final Color separator = AppColors.separator.resolveFrom(context);
    final double hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: AppRadius.mediumAll,
      child: ColoredBox(
        color: AppColors.surface.resolveFrom(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < foods.length; i++) ...<Widget>[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sectionPadding,
                  ),
                  child: SizedBox(
                    height: hairline,
                    width: double.infinity,
                    child: ColoredBox(color: separator),
                  ),
                ),
              _ResultRow(food: foods.elementAt(i), onTap: onTap),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.food, required this.onTap});

  final Food food;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey<String>('food-result-${food.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(food),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.giant),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sectionPadding,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        food.name,
                        style: AppTypography.headline.copyWith(
                          color: AppColors.textPrimary.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        describeFood(food),
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: AppIconSize.inline,
                  color: AppColors.textTertiary.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color textSecondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppIconSize.emptyState, color: textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(
              color: AppColors.textPrimary.resolveFrom(context),
            ),
          ),
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.itemGapTight),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.subheadline.copyWith(color: textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
