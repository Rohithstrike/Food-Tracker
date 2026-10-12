// Serving definitions: how a household unit maps to a weight.
//
// There is no universal weight for "1 bowl" or "1 idli". Each food defines
// its own servings, and each serving records how reliable its weight is.

/// How reliable a serving's weight is.
enum ServingWeightBasis {
  /// A defined unit, such as 1 g.
  exact,

  /// Taken from a documented measurement or source.
  measured,

  /// A reasonable estimate. Results using it are marked as estimates.
  estimated,
}

/// One way of measuring a food, for example "1 piece" weighing 40 g.
final class Serving {
  Serving({
    required String id,
    required String singularLabel,
    required String pluralLabel,
    required num grams,
    required this.weightBasis,
    this.note,
  }) : id = _requireText(id, 'id'),
       singularLabel = _requireText(singularLabel, 'singularLabel'),
       pluralLabel = _requireText(pluralLabel, 'pluralLabel'),
       milligrams = _gramsToMilligrams(grams);

  /// The 1 g serving that every food has automatically.
  factory Serving.gram() => Serving(
    id: gramId,
    singularLabel: 'g',
    pluralLabel: 'g',
    grams: 1,
    weightBasis: ServingWeightBasis.exact,
  );

  static const String gramId = 'g';

  /// Largest weight a single serving may define.
  static const int maxGrams = 5000;

  final String id;
  final String singularLabel;
  final String pluralLabel;

  /// Weight of ONE serving, in milligrams.
  final int milligrams;

  final ServingWeightBasis weightBasis;

  /// Optional explanation, such as where the weight came from.
  final String? note;

  double get grams => milligrams / 1000;

  String labelFor(num quantity) => quantity == 1 ? singularLabel : pluralLabel;
}

int _gramsToMilligrams(num grams) {
  if (!grams.isFinite || grams <= 0 || grams > Serving.maxGrams) {
    throw ArgumentError.value(
      grams,
      'grams',
      'must be a positive weight up to ${Serving.maxGrams} g',
    );
  }
  final int milligrams = (grams * 1000).round();
  if (milligrams <= 0) {
    throw ArgumentError.value(grams, 'grams', 'is too small (minimum 1 mg)');
  }
  return milligrams;
}

String _requireText(String value, String name) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return trimmed;
}
