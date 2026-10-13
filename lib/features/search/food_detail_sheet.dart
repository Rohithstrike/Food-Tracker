// Food detail sheet: choose serving, quantity and added oil, and see the
// nutrition update live.
//
// Every number comes from EntryBuilder, which uses the existing
// NutritionEngine. Unknown nutrients are shown as "Not available", never as
// zero. Adding to a meal arrives in the next batch, so this sheet has no
// "Add" button yet.

import 'package:flutter/cupertino.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_typography.dart';
import '../../domain/food/food.dart';
import '../../domain/food/serving.dart';
import '../../domain/log/entry_builder.dart';
import '../../domain/log/log_entry.dart';
import '../../domain/nutrition/nutrition.dart';
import '../../domain/nutrition/nutrition_engine.dart';
import 'food_controls.dart';
import 'food_labels.dart';

/// Opens the detail sheet for [food] above the tab bar.
Future<void> showFoodDetailSheet(
  BuildContext context, {
  required Food food,
  Food? oilFood,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (BuildContext context) =>
      FoodDetailSheet(food: food, oilFood: oilFood),
);

/// Shown first, in this order. Other nutrients appear only when known.
const List<NutrientKind> _mainNutrients = <NutrientKind>[
  NutrientKind.protein,
  NutrientKind.carbohydrates,
  NutrientKind.fat,
  NutrientKind.fibre,
  NutrientKind.sugar,
  NutrientKind.sodium,
];

class FoodDetailSheet extends StatefulWidget {
  const FoodDetailSheet({super.key, required this.food, this.oilFood});

  final Food food;

  /// The oil used for "Added oil". Null hides the oil controls.
  final Food? oilFood;

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  late String _servingId = defaultServingId(widget.food);
  late num _quantity = defaultQuantityFor(_servingId);
  num _oilGrams = 0;

  Serving get _serving => widget.food.servingById(_servingId)!;

  void _selectServing(String id) {
    if (id == _servingId) {
      return;
    }
    setState(() {
      _servingId = id;
      _quantity = defaultQuantityFor(id);
    });
  }

  bool _canChangeQuantity(int direction) {
    final num next = _quantity + direction * quantityStepFor(_servingId);
    return next >= quantityStepFor(_servingId) &&
        next <= maxQuantityFor(_servingId);
  }

  void _changeQuantity(int direction) {
    if (_canChangeQuantity(direction)) {
      setState(() {
        _quantity += direction * quantityStepFor(_servingId);
      });
    }
  }

  bool _canChangeOil(int direction) {
    final num next = _oilGrams + direction * oilStepGrams;
    return next >= 0 && next <= maxOilGrams;
  }

  void _changeOil(int direction) {
    if (_canChangeOil(direction)) {
      setState(() {
        _oilGrams += direction * oilStepGrams;
      });
    }
  }

  LogEntry? _preview() {
    final DateTime now = DateTime.now();
    final Food? oil = widget.oilFood;
    try {
      return EntryBuilder.build(
        id: 'preview',
        date: LocalDate.fromDateTime(now),
        mealSlotId: 'preview',
        timestamp: now,
        base: FoodPortion(
          food: widget.food,
          servingId: _servingId,
          quantity: _quantity,
        ),
        oil: oil,
        oilGrams: oil == null ? 0 : _oilGrams,
      );
    } on NutritionInputException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Food food = widget.food;
    final LogEntry? entry = _preview();
    final Color textPrimary = AppColors.textPrimary.resolveFrom(context);
    final Color textSecondary = AppColors.textSecondary.resolveFrom(context);
    final TextStyle note = AppTypography.footnote.copyWith(
      color: textSecondary,
    );
    final bool isGrams = _servingId == Serving.gramId;

    final List<Widget> content = <Widget>[
      Text(food.name, style: AppTypography.title.copyWith(color: textPrimary)),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          if (food.isSample) const InfoTag(label: 'Sample data'),
          InfoTag(label: stateLabel(food.state)),
          if (entry != null && entry.isEstimate)
            const InfoTag(label: 'Estimate'),
        ],
      ),
      if (food.isSample) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(sampleDataNotice, style: note),
      ],
      const SizedBox(height: AppSpacing.xl),
      if (food.servings.length > 1) ...<Widget>[
        const SectionLabel('Serving'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final Serving serving in food.servings)
              SelectableChip(
                key: ValueKey<String>('serving-${serving.id}'),
                label: servingChipLabel(serving),
                selected: serving.id == _servingId,
                onTap: () => _selectServing(serving.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      const SectionLabel('Quantity'),
      const SizedBox(height: AppSpacing.xs),
      QuantityStepper(
        keyPrefix: 'detail-qty',
        valueText:
            '${formatQuantity(_quantity)} ${_serving.labelFor(_quantity)}',
        detail: isGrams || entry == null
            ? null
            : 'About ${formatWeight(entry.base.nutrition.totalMilligrams)} g',
        decreaseLabel: 'Decrease quantity',
        increaseLabel: 'Increase quantity',
        onDecrease: _canChangeQuantity(-1) ? () => _changeQuantity(-1) : null,
        onIncrease: _canChangeQuantity(1) ? () => _changeQuantity(1) : null,
      ),
      if (widget.oilFood != null) ...<Widget>[
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Added oil'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final OilLevel level in OilLevel.values)
              SelectableChip(
                key: ValueKey<String>('oil-${level.name}'),
                label: level.label,
                selected: _oilGrams == level.defaultGrams,
                onTap: () => setState(() {
                  _oilGrams = level.defaultGrams;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        QuantityStepper(
          keyPrefix: 'detail-oil',
          valueText: '${formatQuantity(_oilGrams)} g oil',
          detail: 'Estimate. Adjust if you know the amount.',
          decreaseLabel: 'Less oil',
          increaseLabel: 'More oil',
          onDecrease: _canChangeOil(-1) ? () => _changeOil(-1) : null,
          onIncrease: _canChangeOil(1) ? () => _changeOil(1) : null,
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      const SectionLabel('Nutrition'),
      const SizedBox(height: AppSpacing.sm),
      if (entry == null)
        Text('Nutrition could not be calculated for this amount.', style: note)
      else
        _NutritionPreview(totals: entry.totals),
      if (entry != null && entry.assumptions.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        const SectionLabel('About these values'),
        const SizedBox(height: AppSpacing.xs),
        for (final String assumption in entry.assumptions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text('\u2022 $assumption', style: note),
          ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Adding food to a meal arrives in the next update.',
        textAlign: TextAlign.center,
        style: note,
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SheetHeader(onDone: () => Navigator.of(context).pop()),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      0,
                      AppSpacing.pageMargin,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: SizedBox(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxs,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.separator.resolveFrom(context),
                borderRadius: AppRadius.capsuleAll,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: CupertinoButton(
              key: const ValueKey<String>('detail-done'),
              onPressed: onDone,
              child: Text(
                'Done',
                style: AppTypography.headline.copyWith(
                  color: AppColors.accent.resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({required this.totals});

  final NutritionTotals totals;

  bool _isUnavailable(NutrientKind kind) =>
      totals[kind].missingCount >= totals.itemCount;

  String _valueText(NutrientKind kind) {
    if (_isUnavailable(kind)) {
      return 'Not available';
    }
    final NutrientTotal total = totals[kind];
    final String value = '${formatAmount(total.amount, kind)} ${kind.unit}';
    return total.isComplete ? value : '$value (incomplete)';
  }

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = AppColors.textPrimary.resolveFrom(context);
    final Color textSecondary = AppColors.textSecondary.resolveFrom(context);
    final NutrientTotal energy = totals[NutrientKind.energy];
    final bool energyUnavailable = _isUnavailable(NutrientKind.energy);
    final List<NutrientKind> extras = NutrientKind.values
        .where((NutrientKind kind) => !kind.isCore && !_isUnavailable(kind))
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.resolveFrom(context),
        borderRadius: AppRadius.mediumAll,
      ),
      child: Padding(
        padding: AppSpacing.sectionInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.xs,
              children: <Widget>[
                Text(
                  energyUnavailable
                      ? '\u2014'
                      : formatAmount(energy.amount, NutrientKind.energy),
                  key: const ValueKey<String>('detail-kcal'),
                  style: AppTypography.numericDisplay.copyWith(
                    color: textPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    'kcal',
                    style: AppTypography.numericUnit.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (energyUnavailable || !energy.isComplete)
              Text(
                energyUnavailable
                    ? 'Energy not available'
                    : 'Incomplete: some parts have no energy value',
                style: AppTypography.footnote.copyWith(color: textSecondary),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final NutrientKind kind in <NutrientKind>[
              ..._mainNutrients,
              ...extras,
            ])
              _NutrientRow(label: kind.label, value: _valueText(kind)),
          ],
        ),
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textPrimary.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
