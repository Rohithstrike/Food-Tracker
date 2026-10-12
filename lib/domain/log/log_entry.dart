// Logged food entries and their storage format.
//
// A LogEntry is one thing the user ate in one meal: a base food plus,
// optionally, added oil and extras (butter, ghee, cream, sauces...).
//
// SNAPSHOTS: every component keeps the nutrition calculated at the moment it
// was logged (a CalculatedNutrition from the existing NutritionEngine). The
// entry never refers back to the live food record, so later corrections to
// food data never silently change past days. Entry totals are always derived
// from these frozen component values with NutritionEngine.total.
//
// STORAGE: toJson/fromJson produce plain maps (text, numbers, lists), ready
// for the persistence batch. Enum NAMES are stored, never indexes, so the
// order of enum values can never corrupt saved data.

import '../food/food.dart';
import '../nutrition/nutrition.dart';
import '../nutrition/nutrition_engine.dart';

/// A calendar date in the user's local time zone, with no time of day.
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.year, this.month, this.day);

  /// A real calendar date. Throws [ArgumentError] for dates such as 30 Feb.
  factory LocalDate(int year, int month, int day) {
    if (!_isValid(year, month, day)) {
      throw ArgumentError('Not a real calendar date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  /// The local calendar day of [moment]. A meal logged at 23:59 belongs to
  /// that day, not the next.
  factory LocalDate.fromDateTime(DateTime moment) {
    final DateTime local = moment.toLocal();
    return LocalDate._(local.year, local.month, local.day);
  }

  /// Parses "yyyy-mm-dd". Throws [FormatException] for anything else.
  factory LocalDate.parse(String text) {
    final RegExpMatch? match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Expected a date as yyyy-mm-dd', text);
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (!_isValid(year, month, day)) {
      throw FormatException('Not a real calendar date', text);
    }
    return LocalDate._(year, month, day);
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static bool _isValid(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      return false;
    }
    final DateTime check = DateTime(year, month, day);
    return check.year == year && check.month == month && check.day == day;
  }

  /// "yyyy-mm-dd", the stored form.
  String toIsoString() {
    final String y = year.toString().padLeft(4, '0');
    final String m = month.toString().padLeft(2, '0');
    final String d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Local midnight at the start of this date.
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoString();
}

/// What part of an entry a component is.
enum ComponentRole {
  /// The food itself. Every entry has exactly one, listed first.
  base,

  /// Added cooking oil. Always labelled as an estimate.
  oil,

  /// Additions such as butter, ghee, cream or sauces.
  extra,
}

/// One part of a logged entry, with its frozen nutrition snapshot.
final class EntryComponent {
  EntryComponent({
    required this.role,
    required String foodName,
    required this.dataStatus,
    required this.foodState,
    required this.nutrition,
    this.yieldFactorPermille,
  }) : foodName = _requireText(foodName, 'foodName') {
    final int? factor = yieldFactorPermille;
    if (factor != null && factor <= 0) {
      throw ArgumentError.value(
        factor,
        'yieldFactorPermille',
        'must be positive when set',
      );
    }
  }

  /// Snapshot of [food] as it was calculated now.
  factory EntryComponent.fromCalculation({
    required ComponentRole role,
    required Food food,
    required CalculatedNutrition nutrition,
  }) {
    if (nutrition.foodId != food.id) {
      throw ArgumentError(
        'Calculation is for ${nutrition.foodId}, not ${food.id}.',
      );
    }
    return EntryComponent(
      role: role,
      foodName: food.name,
      dataStatus: food.status,
      foodState: food.state,
      nutrition: nutrition,
    );
  }

  factory EntryComponent.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> rawNutrients = _asMap(
      json['nutrients'],
      'nutrients',
    );
    final Map<NutrientKind, NutrientAmount> known =
        <NutrientKind, NutrientAmount>{};
    for (final MapEntry<String, Object?> entry in rawNutrients.entries) {
      final NutrientKind kind = _enumByName(
        NutrientKind.values,
        entry.key,
        'nutrient',
      );
      final Object? milli = entry.value;
      if (milli is! int || milli < 0) {
        throw FormatException(
          'Invalid amount for nutrient ${entry.key}: $milli',
        );
      }
      known[kind] = NutrientAmount.milli(milli);
    }

    return EntryComponent(
      role: _enumByName(ComponentRole.values, json['role'], 'role'),
      foodName: _string(json, 'foodName'),
      dataStatus: _enumByName(
        DataStatus.values,
        json['dataStatus'],
        'dataStatus',
      ),
      foodState: _enumByName(FoodState.values, json['foodState'], 'foodState'),
      yieldFactorPermille: _optionalInt(json, 'yieldFactorPermille'),
      nutrition: CalculatedNutrition(
        foodId: _string(json, 'foodId'),
        servingId: _string(json, 'servingId'),
        variantId: _optionalString(json, 'variantId'),
        quantityMilli: _int(json, 'quantityMilli'),
        totalMilligrams: _int(json, 'totalMilligrams'),
        nutrients: NutrientProfile(known),
        isSample: _bool(json, 'isSample'),
        isEstimate: _bool(json, 'isEstimate'),
        assumptions: _stringList(json, 'assumptions'),
      ),
    );
  }

  final ComponentRole role;

  /// Copied at log time, so history keeps the name the user saw.
  final String foodName;
  final DataStatus dataStatus;

  /// Whether the food record's values were raw, cooked or ready to eat.
  final FoodState foodState;

  /// Frozen nutrition for this component (from NutritionEngine.calculate).
  final CalculatedNutrition nutrition;

  /// Reserved for raw/cooked weight conversion (cooked = raw x factor/1000).
  /// Always null for now: no conversion runs until documented cooking-yield
  /// data is added. When set, the component counts as an estimate.
  final int? yieldFactorPermille;

  String get foodId => nutrition.foodId;
  bool get isSample => nutrition.isSample;
  bool get isEstimate => nutrition.isEstimate || yieldFactorPermille != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'foodId': nutrition.foodId,
    'foodName': foodName,
    'dataStatus': dataStatus.name,
    'foodState': foodState.name,
    'servingId': nutrition.servingId,
    'variantId': nutrition.variantId,
    'quantityMilli': nutrition.quantityMilli,
    'totalMilligrams': nutrition.totalMilligrams,
    'isSample': nutrition.isSample,
    'isEstimate': nutrition.isEstimate,
    'assumptions': nutrition.assumptions,
    'yieldFactorPermille': yieldFactorPermille,
    'nutrients': <String, int>{
      for (final MapEntry<NutrientKind, NutrientAmount> entry
          in nutrition.nutrients.known.entries)
        entry.key.name: entry.value.milli,
    },
  };
}

/// One logged item in one meal on one local date.
final class LogEntry {
  LogEntry({
    required String id,
    required this.date,
    required String mealSlotId,
    required this.createdAt,
    required this.updatedAt,
    required List<EntryComponent> components,
  }) : id = _requireText(id, 'id'),
       mealSlotId = _requireText(mealSlotId, 'mealSlotId'),
       components = List<EntryComponent>.unmodifiable(components) {
    if (components.isEmpty || components.first.role != ComponentRole.base) {
      throw ArgumentError('An entry must start with its base food.');
    }
    final int bases = components
        .where((EntryComponent c) => c.role == ComponentRole.base)
        .length;
    if (bases != 1) {
      throw ArgumentError('An entry must have exactly one base food.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt.');
    }
  }

  factory LogEntry.fromJson(Map<String, Object?> json) {
    final int version = _int(json, 'schemaVersion');
    if (version != schemaVersion) {
      throw FormatException('Unsupported log entry schema version: $version');
    }
    final Object? rawComponents = json['components'];
    if (rawComponents is! List) {
      throw const FormatException('Expected a list for "components".');
    }
    return LogEntry(
      id: _string(json, 'id'),
      date: LocalDate.parse(_string(json, 'date')),
      mealSlotId: _string(json, 'mealSlotId'),
      createdAt: DateTime.parse(_string(json, 'createdAt')),
      updatedAt: DateTime.parse(_string(json, 'updatedAt')),
      components: <EntryComponent>[
        for (final Object? raw in rawComponents)
          EntryComponent.fromJson(_asMap(raw, 'component')),
      ],
    );
  }

  /// Version of the stored format. Increase it when the format changes.
  static const int schemaVersion = 1;

  final String id;
  final LocalDate date;

  /// The meal slot's PERMANENT id (e.g. "lunch"), never its display name.
  final String mealSlotId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Base first, then oil and extras.
  final List<EntryComponent> components;

  EntryComponent get base => components.first;

  /// Totals of the frozen component snapshots. Unknown nutrients are
  /// counted as missing, never as zero.
  late final NutritionTotals totals = NutritionEngine.total(
    components.map((EntryComponent c) => c.nutrition),
  );

  bool get isSample => components.any((EntryComponent c) => c.isSample);
  bool get isEstimate => components.any((EntryComponent c) => c.isEstimate);

  /// Every explanation from every component, without duplicates.
  List<String> get assumptions {
    final List<String> result = <String>[];
    for (final EntryComponent component in components) {
      for (final String text in component.nutrition.assumptions) {
        if (!result.contains(text)) {
          result.add(text);
        }
      }
    }
    return List<String>.unmodifiable(result);
  }

  /// Same entry (same id and creation time) with changes, e.g. moved to
  /// another meal or rebuilt with a new quantity.
  LogEntry copyWith({
    LocalDate? date,
    String? mealSlotId,
    DateTime? updatedAt,
    List<EntryComponent>? components,
  }) => LogEntry(
    id: id,
    date: date ?? this.date,
    mealSlotId: mealSlotId ?? this.mealSlotId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    components: components ?? this.components,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'id': id,
    'date': date.toIsoString(),
    'mealSlotId': mealSlotId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'components': <Map<String, Object?>>[
      for (final EntryComponent component in components) component.toJson(),
    ],
  };
}

// ---------------------------------------------------------------------------
// Strict JSON readers: wrong or missing data fails loudly, never guessed.
// ---------------------------------------------------------------------------

T _enumByName<T extends Enum>(List<T> values, Object? raw, String what) {
  if (raw is String) {
    for (final T value in values) {
      if (value.name == raw) {
        return value;
      }
    }
  }
  throw FormatException('Unknown $what: $raw');
}

Map<String, Object?> _asMap(Object? raw, String what) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  throw FormatException('Expected an object for "$what".');
}

String _string(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected text for "$key".');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected text or null for "$key".');
}

int _int(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected a whole number for "$key".');
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Expected a whole number or null for "$key".');
}

bool _bool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected true or false for "$key".');
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! List) {
    throw FormatException('Expected a list for "$key".');
  }
  final List<String> result = <String>[];
  for (final Object? item in raw) {
    if (item is! String) {
      throw FormatException('Expected text items in "$key".');
    }
    result.add(item);
  }
  return result;
}

String _requireText(String value, String name) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return trimmed;
}
