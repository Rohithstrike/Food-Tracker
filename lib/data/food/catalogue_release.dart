// Versioned catalogue releases: the contract that real food data must satisfy
// before it can enter search.
//
// A release is one JSON document holding a catalogue id, a release id, the
// upstream sources the data came from, and the foods themselves. Parsing a
// release IS the validation gate: either every record is valid and the whole
// release is returned, or nothing is returned and a
// CatalogueValidationException lists every problem found. Nothing is repaired,
// guessed or defaulted.
//
// Rules that matter most:
//   - A nutrient the source does not give is null (unknown). It is never
//     stored as zero. The seven core nutrients must be stated explicitly, as a
//     number or as null.
//   - Every food names its source and the record it came from, and every
//     source in a release must have a recorded, cleared licence.
//   - Sample, personal and recipe records are not catalogue records.
//   - Household servings must document where their weight came from.
//
// The format is documented in docs/CatalogueContract.md.

import 'dart:convert';

import '../../domain/food/food.dart';
import '../../domain/food/serving.dart';
import '../../domain/nutrition/nutrition.dart';
import 'food_search.dart';

/// Size limits and plausibility bounds used by validation.
///
/// The nutrient bounds are sanity limits per 100 g of food. They catch unit
/// slips such as grams entered as milligrams. They are not nutrition advice
/// and never reject a physically possible value.
abstract final class CatalogueLimits {
  static const int maxJsonCharacters = 20000000;
  static const int maxFoods = 20000;
  static const int maxSources = 50;
  static const int maxAliasesPerFood = 50;
  static const int maxServingsPerFood = 20;
  static const int maxReportedIssues = 100;

  static const double maxEnergyKcalPer100g = 950;
  static const double maxGramsPer100g = 100;
  static const double maxMilligramsPer100g = 100000;
  static const double maxMicrogramsPer100g = 1000000;

  /// Protein, carbohydrate and fat together cannot exceed 100 g per 100 g of
  /// food. One gram of slack allows for source rounding.
  static const double maxMacroSumGramsPer100g = 101;
}

/// Whether a source's licence has been checked and recorded.
enum SourceLicenceStatus {
  /// Reuse is documented. Only this status may appear in a release.
  cleared,

  /// Written permission has been requested but not yet granted.
  permissionPending,

  /// The licence has not been established.
  unresolved,
}

/// One problem found while validating a release.
final class CatalogueIssue {
  CatalogueIssue(this.path, this.message);

  /// Where the problem is, for example foods[3].nutrients.energy.
  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// A release was rejected. [issues] lists the problems found (up to
/// [CatalogueLimits.maxReportedIssues]); [issueCount] is the true total.
final class CatalogueValidationException implements Exception {
  CatalogueValidationException(List<CatalogueIssue> issues, {int? total})
    : issues = List<CatalogueIssue>.unmodifiable(issues),
      issueCount = total ?? issues.length;

  final List<CatalogueIssue> issues;
  final int issueCount;

  @override
  String toString() {
    final String shown = issues
        .take(10)
        .map((CatalogueIssue issue) => '  - $issue')
        .join('\n');
    final String more = issueCount > 10
        ? '\n  ... and ${issueCount - 10} more'
        : '';
    return 'CatalogueValidationException: $issueCount problem(s)\n$shown$more';
  }
}

/// An upstream data source recorded in a release.
final class CatalogueSource {
  const CatalogueSource({
    required this.id,
    required this.name,
    required this.version,
    required this.licence,
    required this.licenceStatus,
    required this.licenceEvidence,
    required this.retrievedOn,
    this.attribution,
    this.url,
  });

  final String id;
  final String name;

  /// Edition or release of the upstream data, for example a year or edition.
  final String version;
  final String licence;
  final SourceLicenceStatus licenceStatus;

  /// Plain-text evidence that reuse is permitted (for example where the
  /// licence statement is published, or a permission reference).
  final String licenceEvidence;

  /// Date (yyyy-mm-dd) the upstream data was obtained.
  final String retrievedOn;

  /// Credit that must be shown, when the licence requires one.
  final String? attribution;
  final String? url;
}

/// A fully validated catalogue release.
final class CatalogueRelease {
  CatalogueRelease._({
    required this.schemaVersion,
    required this.catalogueId,
    required this.releaseId,
    required this.publishedOn,
    required List<CatalogueSource> sources,
    required List<Food> foods,
    required Map<String, String> sourceIdByFoodId,
  }) : sources = List<CatalogueSource>.unmodifiable(sources),
       foods = List<Food>.unmodifiable(foods),
       _sourceIdByFoodId = Map<String, String>.unmodifiable(sourceIdByFoodId);

  /// Reads a release from JSON text. Throws [CatalogueValidationException]
  /// if the text is not a valid release.
  factory CatalogueRelease.parse(String text) {
    if (text.length > CatalogueLimits.maxJsonCharacters) {
      throw _single(
        'file',
        'is larger than ${CatalogueLimits.maxJsonCharacters} characters',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw _single('file', 'is not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw _single('file', 'must contain one JSON object');
    }
    return CatalogueRelease.fromJson(decoded);
  }

  /// Validates decoded JSON. Throws [CatalogueValidationException] listing
  /// every problem found, or returns a release in which every record is valid.
  factory CatalogueRelease.fromJson(Map<String, Object?> json) {
    final Object? rawSchema = json['schemaVersion'];
    if (rawSchema is! int) {
      throw _single('schemaVersion', 'is required and must be a whole number');
    }
    if (rawSchema != supportedSchemaVersion) {
      throw _single(
        'schemaVersion',
        'is $rawSchema, but this version of the app reads only version '
            '$supportedSchemaVersion',
      );
    }

    final _Issues issues = _Issues();
    _rejectUnknownKeys(json, _releaseKeys, '', issues);

    final String? catalogueId = _readText(
      json,
      'catalogueId',
      '',
      issues,
      mandatory: true,
    );
    if (catalogueId != null && !isValidCatalogueId(catalogueId)) {
      issues.add(
        'catalogueId',
        'must be 2 to 16 lowercase letters or digits, starting with a letter, '
            'and must not be "sample"',
      );
    }
    final String? releaseId = _readText(
      json,
      'releaseId',
      '',
      issues,
      mandatory: true,
    );
    if (releaseId != null && !_releaseIdPattern.hasMatch(releaseId)) {
      issues.add(
        'releaseId',
        'must look like 2026.10.1 (year, month, release number)',
      );
    }
    final String? publishedOn = _readDate(json, 'publishedOn', '', issues);

    final Map<String, CatalogueSource> sources = _parseSources(
      json['sources'],
      issues,
    );

    final List<Food> foods = <Food>[];
    final Map<String, String> sourceIdByFoodId = <String, String>{};
    final List<Object?>? rawFoods = _readList(json['foods'], 'foods', issues);
    if (rawFoods != null) {
      if (rawFoods.isEmpty) {
        issues.add('foods', 'must contain at least one food');
      } else if (rawFoods.length > CatalogueLimits.maxFoods) {
        issues.add(
          'foods',
          'has ${rawFoods.length} foods; the limit is '
              '${CatalogueLimits.maxFoods}',
        );
      } else if (catalogueId != null) {
        final Set<String> seenIds = <String>{};
        final Map<String, String> idByName = <String, String>{};
        for (int i = 0; i < rawFoods.length; i++) {
          final _ParsedFood? parsed = _parseFood(
            raw: rawFoods[i],
            index: i,
            catalogueId: catalogueId,
            sources: sources,
            issues: issues,
          );
          if (parsed == null) {
            continue;
          }
          final Food food = parsed.food;
          if (!seenIds.add(food.id)) {
            issues.add('foods[$i]', 'duplicates the id ${food.id}');
            continue;
          }
          final String searchable = normaliseSearchText(food.name);
          final String? other = idByName[searchable];
          if (other != null) {
            issues.add(
              'foods[$i]',
              '${food.id} has the same searchable name as $other; give each '
                  'distinct food its own name',
            );
            continue;
          }
          idByName[searchable] = food.id;
          foods.add(food);
          sourceIdByFoodId[food.id] = parsed.sourceId;
        }
      }
    }

    if (issues.total > 0 ||
        catalogueId == null ||
        releaseId == null ||
        publishedOn == null) {
      throw CatalogueValidationException(issues.reported, total: issues.total);
    }
    return CatalogueRelease._(
      schemaVersion: supportedSchemaVersion,
      catalogueId: catalogueId,
      releaseId: releaseId,
      publishedOn: publishedOn,
      sources: sources.values.toList(),
      foods: foods,
      sourceIdByFoodId: sourceIdByFoodId,
    );
  }

  /// The only schema version this app can read.
  static const int supportedSchemaVersion = 1;

  /// Catalogue ids that real data may not use.
  static const Set<String> reservedCatalogueIds = <String>{'sample'};

  /// Whether [id] is acceptable as a catalogue id: 2 to 16 lowercase letters
  /// or digits starting with a letter, and not reserved. Food ids in the
  /// catalogue must start with the catalogue id and a colon.
  static bool isValidCatalogueId(String id) =>
      _cataloguePattern.hasMatch(id) && !reservedCatalogueIds.contains(id);

  final int schemaVersion;
  final String catalogueId;

  /// Release number such as 2026.10.1. Corrections are published as a new
  /// release; a published release is never edited.
  final String releaseId;

  /// Date (yyyy-mm-dd) the release was published.
  final String publishedOn;
  final List<CatalogueSource> sources;
  final List<Food> foods;
  final Map<String, String> _sourceIdByFoodId;

  /// The source a food's values came from, or null for an unknown food id.
  CatalogueSource? sourceFor(String foodId) {
    final String? sourceId = _sourceIdByFoodId[foodId];
    if (sourceId == null) {
      return null;
    }
    for (final CatalogueSource source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Patterns and allowed fields
// ---------------------------------------------------------------------------

final RegExp _cataloguePattern = RegExp(r'^[a-z][a-z0-9]{1,15}$');
final RegExp _sourceIdPattern = RegExp(r'^[a-z][a-z0-9_-]{1,31}$');
final RegExp _localIdPattern = RegExp(r'^[a-z][a-z0-9_]{1,63}$');
final RegExp _servingIdPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');
final RegExp _releaseIdPattern = RegExp(r'^\d{4}\.\d{1,2}\.\d{1,4}$');
final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _urlPattern = RegExp(r'^https?://\S+$');

const Set<String> _releaseKeys = <String>{
  'schemaVersion',
  'catalogueId',
  'releaseId',
  'publishedOn',
  'sources',
  'foods',
};

const Set<String> _sourceKeys = <String>{
  'id',
  'name',
  'version',
  'licence',
  'licenceStatus',
  'licenceEvidence',
  'retrievedOn',
  'attribution',
  'url',
};

const Set<String> _foodKeys = <String>{
  'id',
  'name',
  'aliases',
  'category',
  'region',
  'state',
  'preparation',
  'family',
  'variety',
  'status',
  'sourceId',
  'recordId',
  'url',
  'matchNote',
  'nutrients',
  'servings',
  'variants',
};

const Set<String> _servingKeys = <String>{
  'id',
  'singularLabel',
  'pluralLabel',
  'grams',
  'weightBasis',
  'note',
};

// ---------------------------------------------------------------------------
// Issue collection and field readers
// ---------------------------------------------------------------------------

final class _Issues {
  final List<CatalogueIssue> reported = <CatalogueIssue>[];
  int total = 0;

  void add(String path, String message) {
    total++;
    if (reported.length < CatalogueLimits.maxReportedIssues) {
      reported.add(CatalogueIssue(path, message));
    }
  }
}

final class _ParsedFood {
  _ParsedFood(this.food, this.sourceId);

  final Food food;
  final String sourceId;
}

CatalogueValidationException _single(String path, String message) =>
    CatalogueValidationException(<CatalogueIssue>[
      CatalogueIssue(path, message),
    ]);

String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

Map<String, Object?>? _readObject(Object? raw, String path, _Issues issues) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  issues.add(path, 'must be an object');
  return null;
}

List<Object?>? _readList(Object? raw, String path, _Issues issues) {
  if (raw is List<Object?>) {
    return raw;
  }
  issues.add(path, 'must be a list');
  return null;
}

void _rejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  String path,
  _Issues issues,
) {
  for (final String key in json.keys) {
    if (!allowed.contains(key)) {
      issues.add(_join(path, key), 'is not a recognised field');
    }
  }
}

String? _readText(
  Map<String, Object?> json,
  String key,
  String path,
  _Issues issues, {
  required bool mandatory,
}) {
  final String where = _join(path, key);
  final Object? raw = json[key];
  if (raw == null) {
    if (mandatory) {
      issues.add(where, 'is required');
    }
    return null;
  }
  if (raw is! String) {
    issues.add(where, 'must be text');
    return null;
  }
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    issues.add(where, 'must not be blank');
    return null;
  }
  return trimmed;
}

T? _readEnum<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String path,
  _Issues issues, {
  required bool mandatory,
}) {
  final String? name = _readText(json, key, path, issues, mandatory: mandatory);
  if (name == null) {
    return null;
  }
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  issues.add(
    _join(path, key),
    'must be one of: ${values.map((T value) => value.name).join(', ')}',
  );
  return null;
}

bool _isRealDate(String text) {
  final RegExpMatch? match = _datePattern.firstMatch(text);
  if (match == null) {
    return false;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (year < 1) {
    return false;
  }
  final DateTime check = DateTime(year, month, day);
  return check.year == year && check.month == month && check.day == day;
}

String? _readDate(
  Map<String, Object?> json,
  String key,
  String path,
  _Issues issues,
) {
  final String? text = _readText(json, key, path, issues, mandatory: true);
  if (text == null) {
    return null;
  }
  if (!_isRealDate(text)) {
    issues.add(_join(path, key), 'must be a real date written yyyy-mm-dd');
    return null;
  }
  return text;
}

String? _readUrl(
  Map<String, Object?> json,
  String key,
  String path,
  _Issues issues,
) {
  final String? text = _readText(json, key, path, issues, mandatory: false);
  if (text == null) {
    return null;
  }
  if (!_urlPattern.hasMatch(text)) {
    issues.add(_join(path, key), 'must be an https:// or http:// link');
    return null;
  }
  return text;
}

/// True when [value] has at most three decimal places. The app stores
/// nutrient amounts and serving weights in thousandths, so finer detail
/// would be rounded away silently; it is rejected instead.
bool _hasAtMostThreeDecimals(num value) {
  final double scaled = value.toDouble() * 1000;
  return (scaled - scaled.roundToDouble()).abs() <= 0.0001;
}

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

Map<String, CatalogueSource> _parseSources(Object? raw, _Issues issues) {
  final Map<String, CatalogueSource> result = <String, CatalogueSource>{};
  final List<Object?>? list = _readList(raw, 'sources', issues);
  if (list == null) {
    return result;
  }
  if (list.isEmpty) {
    issues.add('sources', 'must list at least one source');
    return result;
  }
  if (list.length > CatalogueLimits.maxSources) {
    issues.add(
      'sources',
      'lists ${list.length} sources; the limit is '
          '${CatalogueLimits.maxSources}',
    );
    return result;
  }
  for (int i = 0; i < list.length; i++) {
    final String path = 'sources[$i]';
    final Map<String, Object?>? json = _readObject(list[i], path, issues);
    if (json == null) {
      continue;
    }
    _rejectUnknownKeys(json, _sourceKeys, path, issues);

    final String? id = _readText(json, 'id', path, issues, mandatory: true);
    if (id != null && !_sourceIdPattern.hasMatch(id)) {
      issues.add(
        '$path.id',
        'must be 2 to 32 characters: lowercase letters, digits, underscores '
            'and hyphens, starting with a letter',
      );
    }
    final String? name = _readText(json, 'name', path, issues, mandatory: true);
    final String? version = _readText(
      json,
      'version',
      path,
      issues,
      mandatory: true,
    );
    final String? licence = _readText(
      json,
      'licence',
      path,
      issues,
      mandatory: true,
    );
    final SourceLicenceStatus? status = _readEnum<SourceLicenceStatus>(
      json,
      'licenceStatus',
      SourceLicenceStatus.values,
      path,
      issues,
      mandatory: true,
    );
    if (status != null && status != SourceLicenceStatus.cleared) {
      issues.add(
        '$path.licenceStatus',
        'is ${status.name}: data from this source cannot be released until '
            'its licence is cleared and the evidence is recorded',
      );
    }
    final String? evidence = _readText(
      json,
      'licenceEvidence',
      path,
      issues,
      mandatory: true,
    );
    final String? retrievedOn = _readDate(json, 'retrievedOn', path, issues);
    final String? attribution = _readText(
      json,
      'attribution',
      path,
      issues,
      mandatory: false,
    );
    final String? url = _readUrl(json, 'url', path, issues);

    if (id == null ||
        name == null ||
        version == null ||
        licence == null ||
        status == null ||
        evidence == null ||
        retrievedOn == null) {
      continue;
    }
    if (result.containsKey(id)) {
      issues.add('$path.id', 'duplicates an earlier source id');
      continue;
    }
    result[id] = CatalogueSource(
      id: id,
      name: name,
      version: version,
      licence: licence,
      licenceStatus: status,
      licenceEvidence: evidence,
      retrievedOn: retrievedOn,
      attribution: attribution,
      url: url,
    );
  }
  return result;
}

// ---------------------------------------------------------------------------
// Foods
// ---------------------------------------------------------------------------

String _statusMessage(String name) => switch (name) {
  'sample' => 'sample data cannot be part of a real catalogue release',
  'userCustom' => 'personal foods are not catalogue records',
  'recipeEstimate' =>
    'recipe records are not supported by schema version 1; add them when the '
        'recipe model exists',
  _ => 'must be "verified"',
};

_ParsedFood? _parseFood({
  required Object? raw,
  required int index,
  required String catalogueId,
  required Map<String, CatalogueSource> sources,
  required _Issues issues,
}) {
  final String path = 'foods[$index]';
  final Map<String, Object?>? json = _readObject(raw, path, issues);
  if (json == null) {
    return null;
  }
  final int issuesBefore = issues.total;
  _rejectUnknownKeys(json, _foodKeys, path, issues);

  final String? id = _readText(json, 'id', path, issues, mandatory: true);
  final String where = id == null ? path : '$path ($id)';
  if (id != null) {
    final String prefix = '$catalogueId:';
    if (!id.startsWith(prefix)) {
      issues.add('$where.id', 'must start with "$prefix"');
    } else if (!_localIdPattern.hasMatch(id.substring(prefix.length))) {
      issues.add(
        '$where.id',
        'text after "$prefix" must be 2 to 64 characters: lowercase letters, '
            'digits and underscores, starting with a letter',
      );
    }
  }

  final String? name = _readText(json, 'name', where, issues, mandatory: true);
  if (name != null && normaliseSearchText(name).isEmpty) {
    issues.add('$where.name', 'must contain letters or digits');
  }

  final List<String> aliases = <String>[];
  final Object? rawAliases = json['aliases'];
  if (rawAliases != null) {
    final List<Object?>? list = _readList(rawAliases, '$where.aliases', issues);
    if (list != null) {
      if (list.length > CatalogueLimits.maxAliasesPerFood) {
        issues.add(
          '$where.aliases',
          'has ${list.length} aliases; the limit is '
              '${CatalogueLimits.maxAliasesPerFood}',
        );
      } else {
        for (int i = 0; i < list.length; i++) {
          final Object? item = list[i];
          if (item is! String || item.trim().isEmpty) {
            issues.add('$where.aliases[$i]', 'must be non-blank text');
          } else {
            aliases.add(item.trim());
          }
        }
      }
    }
  }

  final FoodCategory? category = _readEnum<FoodCategory>(
    json,
    'category',
    FoodCategory.values,
    where,
    issues,
    mandatory: true,
  );
  final FoodRegion? region = _readEnum<FoodRegion>(
    json,
    'region',
    FoodRegion.values,
    where,
    issues,
    mandatory: true,
  );
  final FoodState? state = _readEnum<FoodState>(
    json,
    'state',
    FoodState.values,
    where,
    issues,
    mandatory: true,
  );
  final PreparationMethod? preparation = _readEnum<PreparationMethod>(
    json,
    'preparation',
    PreparationMethod.values,
    where,
    issues,
    mandatory: false,
  );
  final String? family = _readText(
    json,
    'family',
    where,
    issues,
    mandatory: false,
  );
  final String? variety = _readText(
    json,
    'variety',
    where,
    issues,
    mandatory: false,
  );

  final String? statusName = _readText(
    json,
    'status',
    where,
    issues,
    mandatory: true,
  );
  if (statusName != null && statusName != DataStatus.verified.name) {
    issues.add('$where.status', _statusMessage(statusName));
  }

  final String? sourceId = _readText(
    json,
    'sourceId',
    where,
    issues,
    mandatory: true,
  );
  CatalogueSource? source;
  if (sourceId != null) {
    source = sources[sourceId];
    if (source == null) {
      issues.add(
        '$where.sourceId',
        'refers to "$sourceId", which is not listed in sources',
      );
    }
  }
  final String? recordId = _readText(
    json,
    'recordId',
    where,
    issues,
    mandatory: true,
  );
  final String? url = _readUrl(json, 'url', where, issues);
  final String? matchNote = _readText(
    json,
    'matchNote',
    where,
    issues,
    mandatory: false,
  );

  if (json.containsKey('variants')) {
    issues.add(
      '$where.variants',
      'cooking multipliers are not allowed in catalogue records; model each '
          'preparation as its own record',
    );
  }

  final Map<NutrientKind, num?>? nutrients = _parseNutrients(
    json['nutrients'],
    '$where.nutrients',
    issues,
  );
  final List<Serving> servings = _parseServings(
    json['servings'],
    '$where.servings',
    issues,
  );

  if (issues.total != issuesBefore ||
      id == null ||
      name == null ||
      category == null ||
      region == null ||
      state == null ||
      sourceId == null ||
      source == null ||
      recordId == null ||
      nutrients == null) {
    return null;
  }

  final String citation = matchNote == null
      ? '${source.name}, ${source.version}'
      : '${source.name}, ${source.version} (match: $matchNote)';
  final String? attribution = source.attribution;
  final String licenceNote = attribution == null
      ? source.licence
      : '${source.licence}. $attribution';

  try {
    final Food food = Food(
      id: id,
      name: name,
      aliases: aliases,
      category: category,
      region: region,
      per100g: NutrientProfile.fromValues(nutrients),
      servings: servings,
      status: DataStatus.verified,
      source: FoodSource(
        citation: citation,
        licenceNote: licenceNote,
        recordId: recordId,
        url: url,
      ),
      family: family,
      variety: variety,
      preparation: preparation,
      state: state,
    );
    return _ParsedFood(food, sourceId);
  } on ArgumentError catch (error) {
    issues.add(where, 'could not be built: ${error.message}');
    return null;
  }
}

NutrientKind? _nutrientByName(String name) {
  for (final NutrientKind kind in NutrientKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return null;
}

double _maxPer100g(NutrientKind kind) => switch (kind.unit) {
  'kcal' => CatalogueLimits.maxEnergyKcalPer100g,
  'g' => CatalogueLimits.maxGramsPer100g,
  'mg' => CatalogueLimits.maxMilligramsPer100g,
  _ => CatalogueLimits.maxMicrogramsPer100g,
};

/// Reads the per-100 g nutrient values. A null value means the source does
/// not give that nutrient: it stays unknown and is never turned into zero.
Map<NutrientKind, num?>? _parseNutrients(
  Object? raw,
  String path,
  _Issues issues,
) {
  final Map<String, Object?>? json = _readObject(raw, path, issues);
  if (json == null) {
    return null;
  }
  final Map<NutrientKind, num?> values = <NutrientKind, num?>{};
  for (final MapEntry<String, Object?> entry in json.entries) {
    final String where = _join(path, entry.key);
    final NutrientKind? kind = _nutrientByName(entry.key);
    if (kind == null) {
      issues.add(where, 'is not a known nutrient');
      continue;
    }
    final Object? value = entry.value;
    if (value == null) {
      values[kind] = null;
      continue;
    }
    if (value is! num || !value.isFinite) {
      issues.add(
        where,
        'must be a number, or null when the source has no value',
      );
      continue;
    }
    final double limit = _maxPer100g(kind);
    if (value < 0) {
      issues.add(where, 'must not be negative');
    } else if (value > limit) {
      issues.add(
        where,
        'is above the plausible maximum of ${limit.toStringAsFixed(0)} '
        '${kind.unit} per 100 g',
      );
    } else if (!_hasAtMostThreeDecimals(value)) {
      issues.add(
        where,
        'has more than 3 decimal places; the app stores 0.001 of a unit',
      );
    } else {
      values[kind] = value;
    }
  }

  for (final NutrientKind kind in NutrientKind.values) {
    if (kind.isCore && !json.containsKey(kind.name)) {
      issues.add(
        _join(path, kind.name),
        'must be stated: a number, or null when the source has no value',
      );
    }
  }
  if (json.containsKey(NutrientKind.energy.name) &&
      json[NutrientKind.energy.name] == null) {
    issues.add(
      _join(path, NutrientKind.energy.name),
      'is required: a record without energy cannot be logged',
    );
  }

  double macroSum = 0;
  for (final NutrientKind kind in const <NutrientKind>[
    NutrientKind.protein,
    NutrientKind.carbohydrates,
    NutrientKind.fat,
  ]) {
    final num? value = values[kind];
    if (value != null) {
      macroSum += value;
    }
  }
  if (macroSum > CatalogueLimits.maxMacroSumGramsPer100g) {
    issues.add(
      path,
      'protein, carbohydrates and fat add up to ${macroSum.toStringAsFixed(1)} '
      'g per 100 g, which is not possible (limit '
      '${CatalogueLimits.maxMacroSumGramsPer100g.toStringAsFixed(0)} g '
      'allowing for rounding)',
    );
  }
  return values;
}

/// Reads household servings. Every serving must document where its weight
/// came from, because a bowl or a piece has no universal weight.
List<Serving> _parseServings(Object? raw, String path, _Issues issues) {
  final List<Serving> result = <Serving>[];
  if (raw == null) {
    return result;
  }
  final List<Object?>? list = _readList(raw, path, issues);
  if (list == null) {
    return result;
  }
  if (list.length > CatalogueLimits.maxServingsPerFood) {
    issues.add(
      path,
      'has ${list.length} servings; the limit is '
      '${CatalogueLimits.maxServingsPerFood}',
    );
    return result;
  }
  final Set<String> seen = <String>{Serving.gramId};
  for (int i = 0; i < list.length; i++) {
    final String where = '$path[$i]';
    final Map<String, Object?>? json = _readObject(list[i], where, issues);
    if (json == null) {
      continue;
    }
    _rejectUnknownKeys(json, _servingKeys, where, issues);

    final String? id = _readText(json, 'id', where, issues, mandatory: true);
    if (id != null) {
      if (id == Serving.gramId) {
        issues.add(
          '$where.id',
          'is reserved: every food already has a 1 g serving',
        );
      } else if (!_servingIdPattern.hasMatch(id)) {
        issues.add(
          '$where.id',
          'must be 1 to 32 characters: lowercase letters, digits and '
              'underscores, starting with a letter',
        );
      } else if (!seen.add(id)) {
        issues.add('$where.id', 'duplicates an earlier serving id');
      }
    }
    final String? singular = _readText(
      json,
      'singularLabel',
      where,
      issues,
      mandatory: true,
    );
    final String? plural = _readText(
      json,
      'pluralLabel',
      where,
      issues,
      mandatory: true,
    );

    num? grams;
    final Object? rawGrams = json['grams'];
    if (rawGrams is! num || !rawGrams.isFinite) {
      issues.add('$where.grams', 'is required and must be a number');
    } else if (rawGrams <= 0 || rawGrams > Serving.maxGrams) {
      issues.add(
        '$where.grams',
        'must be above 0 and at most ${Serving.maxGrams} g',
      );
    } else if (!_hasAtMostThreeDecimals(rawGrams)) {
      issues.add('$where.grams', 'has more than 3 decimal places');
    } else {
      grams = rawGrams;
    }

    final ServingWeightBasis? basis = _readEnum<ServingWeightBasis>(
      json,
      'weightBasis',
      ServingWeightBasis.values,
      where,
      issues,
      mandatory: true,
    );
    if (basis == ServingWeightBasis.exact) {
      issues.add(
        '$where.weightBasis',
        'must be measured or estimated: exact is reserved for the built-in '
            'gram serving',
      );
    }
    final String? note = _readText(
      json,
      'note',
      where,
      issues,
      mandatory: true,
    );

    if (id == null ||
        singular == null ||
        plural == null ||
        grams == null ||
        basis == null ||
        note == null) {
      continue;
    }
    try {
      result.add(
        Serving(
          id: id,
          singularLabel: singular,
          pluralLabel: plural,
          grams: grams,
          weightBasis: basis,
          note: note,
        ),
      );
    } on ArgumentError catch (error) {
      issues.add(where, 'could not be built: ${error.message}');
    }
  }
  return result;
}
