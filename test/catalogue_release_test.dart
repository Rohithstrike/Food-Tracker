import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/catalogue_release.dart';
import 'package:indian_food_tracker/data/food/catalogue_release_provider.dart';
import 'package:indian_food_tracker/data/food/food_provider.dart';
import 'package:indian_food_tracker/data/food/food_repository.dart';
import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/food/serving.dart';
import 'package:indian_food_tracker/domain/log/entry_builder.dart';
import 'package:indian_food_tracker/domain/log/log_entry.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition_engine.dart';

// Catalogue release contract. Every name and number below is a TEST FIXTURE
// with placeholder values, not real nutrition data. Tamil text is written as
// Unicode escapes so the file is encoding-safe.

// Tamil "muttai" (egg).
const String tamilEgg = '\u0BAE\u0BC1\u0B9F\u0BCD\u0B9F\u0BC8';

Map<String, Object?> _source() => <String, Object?>{
  'id': 'srcone',
  'name': 'Test Source',
  'version': 'Edition 1',
  'licence': 'Test licence',
  'licenceStatus': 'cleared',
  'licenceEvidence': 'Test evidence text',
  'retrievedOn': '2026-10-01',
  'attribution': 'Test attribution',
  'url': 'https://example.org/source',
};

Map<String, Object?> _food() => <String, Object?>{
  'id': 'ift:test_egg',
  'name': 'Test egg',
  'aliases': <Object?>['eggy', tamilEgg],
  'category': 'ingredient',
  'region': 'panIndian',
  'state': 'cooked',
  'preparation': 'boiled',
  'family': 'Egg',
  'variety': 'Whole',
  'status': 'verified',
  'sourceId': 'srcone',
  'recordId': 'REC-1',
  'url': 'https://example.org/record/1',
  'matchNote': 'Test match note',
  'nutrients': <String, Object?>{
    'energy': 150,
    'protein': 12.5,
    'carbohydrates': 1,
    'fat': 10,
    'fibre': 0,
    'sugar': null,
    'sodium': 120,
    'iron': 1.2,
  },
  'servings': <Object?>[
    <String, Object?>{
      'id': 'piece',
      'singularLabel': 'piece',
      'pluralLabel': 'pieces',
      'grams': 50,
      'weightBasis': 'estimated',
      'note': 'Test note on the weight of one piece',
    },
  ],
};

Map<String, Object?> _release() => <String, Object?>{
  'schemaVersion': 1,
  'catalogueId': 'ift',
  'releaseId': '2026.10.1',
  'publishedOn': '2026-10-20',
  'sources': <Object?>[_source()],
  'foods': <Object?>[_food()],
};

Map<String, Object?> _foodOf(Map<String, Object?> release) =>
    (release['foods']! as List<Object?>).first! as Map<String, Object?>;

Map<String, Object?> _sourceOf(Map<String, Object?> release) =>
    (release['sources']! as List<Object?>).first! as Map<String, Object?>;

Map<String, Object?> _nutrientsOf(Map<String, Object?> release) =>
    _foodOf(release)['nutrients']! as Map<String, Object?>;

Map<String, Object?> _servingOf(Map<String, Object?> release) =>
    (_foodOf(release)['servings']! as List<Object?>).first!
        as Map<String, Object?>;

CatalogueRelease _parse(Map<String, Object?> release) =>
    CatalogueRelease.fromJson(release);

CatalogueValidationException _rejection(Map<String, Object?> release) {
  try {
    CatalogueRelease.fromJson(release);
  } on CatalogueValidationException catch (error) {
    return error;
  }
  fail('Expected the release to be rejected.');
}

/// Expects the release to be rejected with one issue whose text contains both
/// [where] (the location) and [what] (the explanation).
void _expectRejected(Map<String, Object?> release, String where, String what) {
  final CatalogueValidationException error = _rejection(release);
  expect(
    error.issues.map((CatalogueIssue issue) => issue.toString()),
    anyElement(allOf(contains(where), contains(what))),
    reason: error.toString(),
  );
}

Future<String> Function() _loaderOf(Map<String, Object?> release) =>
    () async => jsonEncode(release);

CatalogueReleaseProvider _provider(Map<String, Object?> release) =>
    CatalogueReleaseProvider(catalogueId: 'ift', readJson: _loaderOf(release));

void main() {
  group('A valid release', () {
    test('is read completely', () {
      final CatalogueRelease release = _parse(_release());
      expect(release.schemaVersion, 1);
      expect(release.catalogueId, 'ift');
      expect(release.releaseId, '2026.10.1');
      expect(release.publishedOn, '2026-10-20');
      expect(release.sources.single.id, 'srcone');
      expect(release.sources.single.licenceStatus, SourceLicenceStatus.cleared);

      final Food egg = release.foods.single;
      expect(egg.id, 'ift:test_egg');
      expect(egg.name, 'Test egg');
      expect(egg.aliases, <String>['eggy', tamilEgg]);
      expect(egg.category, FoodCategory.ingredient);
      expect(egg.region, FoodRegion.panIndian);
      expect(egg.state, FoodState.cooked);
      expect(egg.preparation, PreparationMethod.boiled);
      expect(egg.family, 'Egg');
      expect(egg.variety, 'Whole');
      expect(egg.status, DataStatus.verified);
      expect(egg.isSample, isFalse);
    });

    test('keeps the provenance of every food', () {
      final CatalogueRelease release = _parse(_release());
      final Food egg = release.foods.single;
      expect(egg.source?.recordId, 'REC-1');
      expect(egg.source?.url, 'https://example.org/record/1');
      expect(
        egg.source?.citation,
        'Test Source, Edition 1 (match: Test match note)',
      );
      expect(egg.source?.licenceNote, 'Test licence. Test attribution');
      expect(release.sourceFor('ift:test_egg')?.id, 'srcone');
      expect(release.sourceFor('ift:missing'), isNull);
    });

    test('keeps unknown nutrients unknown and zero as a known zero', () {
      final Food egg = _parse(_release()).foods.single;
      expect(
        egg.per100g[NutrientKind.energy],
        const NutrientAmount.milli(150000),
      );
      expect(
        egg.per100g[NutrientKind.protein],
        const NutrientAmount.milli(12500),
      );
      // Stated as null: unknown, not zero.
      expect(egg.per100g[NutrientKind.sugar], isNull);
      expect(egg.per100g.isKnown(NutrientKind.sugar), isFalse);
      // Stated as 0: a real, known zero.
      expect(egg.per100g[NutrientKind.fibre], NutrientAmount.zero);
      expect(egg.per100g.isKnown(NutrientKind.fibre), isTrue);
      // A micronutrient that is given, and one that is simply absent.
      expect(egg.per100g[NutrientKind.iron], const NutrientAmount.milli(1200));
      expect(egg.per100g[NutrientKind.calcium], isNull);
    });

    test('optional fields may be left out', () {
      final Map<String, Object?> release = _release();
      final Map<String, Object?> food = _foodOf(release);
      for (final String key in <String>[
        'aliases',
        'preparation',
        'family',
        'variety',
        'url',
        'matchNote',
        'servings',
      ]) {
        food.remove(key);
      }
      (food['nutrients']! as Map<String, Object?>).remove('iron');
      final Map<String, Object?> source = _sourceOf(release);
      source.remove('attribution');
      source.remove('url');

      final Food egg = _parse(release).foods.single;
      expect(egg.aliases, isEmpty);
      expect(egg.preparation, isNull);
      expect(egg.servings.single.id, Serving.gramId);
      expect(egg.source?.citation, 'Test Source, Edition 1');
      expect(egg.source?.licenceNote, 'Test licence');
      expect(egg.per100g[NutrientKind.iron], isNull);
    });

    test('parses from JSON text', () {
      final CatalogueRelease release = CatalogueRelease.parse(
        jsonEncode(_release()),
      );
      expect(release.foods.length, 1);
    });
  });

  group('The release itself', () {
    test('an unsupported or missing schema version is rejected first', () {
      final Map<String, Object?> future = _release()..['schemaVersion'] = 2;
      final CatalogueValidationException error = _rejection(future);
      expect(error.issues.single.path, 'schemaVersion');
      expect(error.issues.single.message, contains('reads only version 1'));

      final Map<String, Object?> missing = _release()..remove('schemaVersion');
      _expectRejected(missing, 'schemaVersion', 'whole number');
    });

    test('text that is not a JSON object is rejected', () {
      expect(
        () => CatalogueRelease.parse('{not json'),
        throwsA(isA<CatalogueValidationException>()),
      );
      expect(
        () => CatalogueRelease.parse('[1, 2]'),
        throwsA(isA<CatalogueValidationException>()),
      );
    });

    test('catalogue ids must be valid, and "sample" is reserved', () {
      for (final String bad in <String>['sample', 'Ift', 'i', '1ift', '']) {
        final Map<String, Object?> release = _release()..['catalogueId'] = bad;
        expect(
          () => _parse(release),
          throwsA(isA<CatalogueValidationException>()),
          reason: 'catalogueId "$bad"',
        );
      }
    });

    test('release id and publication date must be well formed', () {
      _expectRejected(
        _release()..['releaseId'] = 'latest',
        'releaseId',
        'must look like',
      );
      _expectRejected(
        _release()..['publishedOn'] = '2026-02-30',
        'publishedOn',
        'real date',
      );
    });

    test('unrecognised fields are rejected, not ignored', () {
      _expectRejected(
        _release()..['extra'] = 1,
        'extra',
        'not a recognised field',
      );
      final Map<String, Object?> release = _release();
      _foodOf(release)['alias'] = 'typo for aliases';
      _expectRejected(release, 'alias', 'not a recognised field');
    });

    test('a release must contain foods', () {
      _expectRejected(
        _release()..['foods'] = <Object?>[],
        'foods',
        'at least one food',
      );
    });
  });

  group('Sources and licences', () {
    test('a source whose licence is not cleared blocks the release', () {
      for (final String status in <String>['permissionPending', 'unresolved']) {
        final Map<String, Object?> release = _release();
        _sourceOf(release)['licenceStatus'] = status;
        _expectRejected(release, 'sources[0].licenceStatus', status);
      }
    });

    test('a cleared source must record its licence evidence', () {
      final Map<String, Object?> release = _release();
      _sourceOf(release).remove('licenceEvidence');
      _expectRejected(release, 'licenceEvidence', 'required');
    });

    test('version, retrieval date, link and status are checked', () {
      final Map<String, Object?> noVersion = _release();
      _sourceOf(noVersion).remove('version');
      _expectRejected(noVersion, 'sources[0].version', 'required');

      final Map<String, Object?> badDate = _release();
      _sourceOf(badDate)['retrievedOn'] = 'yesterday';
      _expectRejected(badDate, 'retrievedOn', 'real date');

      final Map<String, Object?> badUrl = _release();
      _sourceOf(badUrl)['url'] = 'not a link';
      _expectRejected(badUrl, 'sources[0].url', 'link');

      final Map<String, Object?> badStatus = _release();
      _sourceOf(badStatus)['licenceStatus'] = 'maybe';
      _expectRejected(badStatus, 'licenceStatus', 'must be one of');
    });

    test('duplicate source ids and an empty source list are rejected', () {
      final Map<String, Object?> duplicate = _release();
      (duplicate['sources']! as List<Object?>).add(_source());
      _expectRejected(duplicate, 'sources[1].id', 'duplicates');

      _expectRejected(
        _release()..['sources'] = <Object?>[],
        'sources',
        'at least one source',
      );
    });
  });

  group('Food records', () {
    test('ids must start with the catalogue id and be well formed', () {
      final Map<String, Object?> wrongPrefix = _release();
      _foodOf(wrongPrefix)['id'] = 'other:test_egg';
      _expectRejected(wrongPrefix, 'foods[0]', 'must start with "ift:"');

      final Map<String, Object?> badSlug = _release();
      _foodOf(badSlug)['id'] = 'ift:Test Egg';
      _expectRejected(badSlug, 'foods[0]', 'lowercase letters');
    });

    test('duplicate ids and duplicate searchable names are rejected', () {
      final Map<String, Object?> sameId = _release();
      (sameId['foods']! as List<Object?>).add(_food());
      _expectRejected(sameId, 'foods[1]', 'duplicates the id');

      final Map<String, Object?> sameName = _release();
      final Map<String, Object?> second = _food()
        ..['id'] = 'ift:other_egg'
        ..['name'] = '  TEST   egg!! ';
      (sameName['foods']! as List<Object?>).add(second);
      _expectRejected(sameName, 'foods[1]', 'same searchable name');
    });

    test('only verified records are accepted', () {
      final Map<String, String> expected = <String, String>{
        'sample': 'sample data',
        'userCustom': 'personal foods',
        'recipeEstimate': 'recipe records',
        'bogus': 'must be "verified"',
      };
      expected.forEach((String status, String message) {
        final Map<String, Object?> release = _release();
        _foodOf(release)['status'] = status;
        _expectRejected(release, '.status', message);
      });
      final Map<String, Object?> missing = _release();
      _foodOf(missing).remove('status');
      _expectRejected(missing, '.status', 'required');
    });

    test('every food must name its source and source record', () {
      final Map<String, Object?> noSource = _release();
      _foodOf(noSource).remove('sourceId');
      _expectRejected(noSource, '.sourceId', 'required');

      final Map<String, Object?> unknownSource = _release();
      _foodOf(unknownSource)['sourceId'] = 'nosuch';
      _expectRejected(unknownSource, '.sourceId', 'not listed in sources');

      final Map<String, Object?> noRecord = _release();
      _foodOf(noRecord).remove('recordId');
      _expectRejected(noRecord, '.recordId', 'required');
    });

    test('category, region and state are required and checked', () {
      for (final String key in <String>['category', 'region', 'state']) {
        final Map<String, Object?> missing = _release();
        _foodOf(missing).remove(key);
        _expectRejected(missing, '.$key', 'required');

        final Map<String, Object?> unknown = _release();
        _foodOf(unknown)[key] = 'nonsense';
        _expectRejected(unknown, '.$key', 'must be one of');
      }
    });

    test('cooking multipliers are not allowed', () {
      final Map<String, Object?> release = _release();
      _foodOf(release)['variants'] = <Object?>[];
      _expectRejected(release, '.variants', 'cooking multipliers');
    });

    test('aliases must be non-blank text', () {
      final Map<String, Object?> blank = _release();
      _foodOf(blank)['aliases'] = <Object?>['ok', '  '];
      _expectRejected(blank, 'aliases[1]', 'non-blank');

      final Map<String, Object?> notList = _release();
      _foodOf(notList)['aliases'] = 'eggy';
      _expectRejected(notList, '.aliases', 'must be a list');
    });
  });

  group('Nutrients', () {
    test('a core nutrient that is not stated is rejected', () {
      for (final String key in <String>['energy', 'sugar', 'sodium', 'fibre']) {
        final Map<String, Object?> release = _release();
        _nutrientsOf(release).remove(key);
        _expectRejected(release, 'nutrients.$key', 'must be stated');
      }
    });

    test('energy cannot be unknown', () {
      final Map<String, Object?> release = _release();
      _nutrientsOf(release)['energy'] = null;
      _expectRejected(release, 'nutrients.energy', 'cannot be logged');
    });

    test('unknown names and wrong types are rejected', () {
      final Map<String, Object?> unknownName = _release();
      _nutrientsOf(unknownName)['vitaminZ'] = 1;
      _expectRejected(
        unknownName,
        'nutrients.vitaminZ',
        'not a known nutrient',
      );

      for (final Object bad in <Object>['12', true, <Object?>[]]) {
        final Map<String, Object?> release = _release();
        _nutrientsOf(release)['protein'] = bad;
        _expectRejected(release, 'nutrients.protein', 'must be a number');
      }
    });

    test('negative values are rejected', () {
      final Map<String, Object?> release = _release();
      _nutrientsOf(release)['fat'] = -0.5;
      _expectRejected(release, 'nutrients.fat', 'negative');
    });

    test('values with more than three decimal places are rejected', () {
      final Map<String, Object?> tooFine = _release();
      _nutrientsOf(tooFine)['protein'] = 12.3456;
      _expectRejected(tooFine, 'nutrients.protein', '3 decimal places');

      final Map<String, Object?> threeDecimals = _release();
      _nutrientsOf(threeDecimals)['protein'] = 12.345;
      expect(
        _parse(threeDecimals).foods.single.per100g[NutrientKind.protein],
        const NutrientAmount.milli(12345),
      );
    });

    test('implausible magnitudes are rejected', () {
      final Map<String, Object?> energy = _release();
      _nutrientsOf(energy)['energy'] = 951;
      _expectRejected(energy, 'nutrients.energy', 'plausible maximum');

      final Map<String, Object?> grams = _release();
      _nutrientsOf(grams)['fibre'] = 100.001;
      _expectRejected(grams, 'nutrients.fibre', 'plausible maximum');

      final Map<String, Object?> sodium = _release();
      _nutrientsOf(sodium)['sodium'] = 100001;
      _expectRejected(sodium, 'nutrients.sodium', 'plausible maximum');

      final Map<String, Object?> macros = _release();
      _nutrientsOf(macros)
        ..['protein'] = 60
        ..['carbohydrates'] = 30
        ..['fat'] = 12;
      _expectRejected(macros, 'nutrients', 'add up to 102.0 g');
    });

    test('a pure fat at the energy and mass limits is accepted', () {
      final Map<String, Object?> release = _release();
      _nutrientsOf(release)
        ..['energy'] = 900
        ..['protein'] = 0
        ..['carbohydrates'] = 0
        ..['fat'] = 100;
      expect(() => _parse(release), returnsNormally);
    });
  });

  group('Servings', () {
    test('a household serving must document its weight', () {
      final Map<String, Object?> release = _release();
      _servingOf(release).remove('note');
      _expectRejected(release, 'servings[0].note', 'required');
    });

    test('serving ids, basis and weights are checked', () {
      final Map<String, Object?> reserved = _release();
      _servingOf(reserved)['id'] = 'g';
      _expectRejected(reserved, 'servings[0].id', 'reserved');

      final Map<String, Object?> exact = _release();
      _servingOf(exact)['weightBasis'] = 'exact';
      _expectRejected(exact, 'weightBasis', 'measured or estimated');

      final Map<String, Object?> duplicate = _release();
      ((_foodOf(duplicate)['servings']! as List<Object?>)).add(
        Map<String, Object?>.of(_servingOf(duplicate)),
      );
      _expectRejected(duplicate, 'servings[1].id', 'duplicates');

      for (final Object bad in <Object>[0, -5, 5001, 12.3456, '50']) {
        final Map<String, Object?> release = _release();
        _servingOf(release)['grams'] = bad;
        _expectRejected(release, 'servings[0].grams', 'grams');
      }
    });
  });

  group('Reporting', () {
    test('every problem is reported together', () {
      final Map<String, Object?> release = _release();
      _foodOf(release)['status'] = 'sample';
      _nutrientsOf(release).remove('energy');
      _sourceOf(release)['licenceStatus'] = 'unresolved';
      final CatalogueValidationException error = _rejection(release);
      expect(error.issues.length, greaterThanOrEqualTo(3));
      expect(error.issueCount, error.issues.length);
      expect(error.toString(), contains('problem(s)'));
    });
  });

  group('Provider and repository', () {
    test('the provider refuses a reserved or malformed catalogue id', () {
      for (final String bad in <String>['sample', 'Bad', '']) {
        expect(
          () => CatalogueReleaseProvider(
            catalogueId: bad,
            readJson: () async => '',
          ),
          throwsArgumentError,
          reason: 'catalogueId "$bad"',
        );
      }
    });

    test('a release for another catalogue is rejected', () async {
      final CatalogueReleaseProvider provider = CatalogueReleaseProvider(
        catalogueId: 'other',
        readJson: _loaderOf(_release()),
      );
      await expectLater(
        provider.loadFoods(),
        throwsA(isA<CatalogueValidationException>()),
      );
    });

    test('the release is available only after a successful load', () async {
      final CatalogueReleaseProvider provider = _provider(_release());
      expect(provider.release, isNull);
      expect(provider.source.id, 'ift');
      expect(provider.source.isSample, isFalse);
      await provider.loadFoods();
      expect(provider.release?.releaseId, '2026.10.1');
    });

    test('real foods search alongside sample foods', () async {
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        const SampleFoodProvider(),
        _provider(_release()),
      ]);
      await repo.load();

      expect(repo.foodCount, buildSampleFoods().length + 1);
      expect(repo.search('test egg').single.food.id, 'ift:test_egg');
      expect(repo.search(tamilEgg).single.food.id, 'ift:test_egg');
      expect(repo.search('idli').first.food.id, 'sample:idli');
      expect(repo.sourceOf('ift:test_egg')?.isSample, isFalse);
      expect(repo.sourceOf('sample:idli')?.isSample, isTrue);
    });

    test(
      'an invalid release never reaches search, and loading can retry',
      () async {
        int calls = 0;
        final FoodRepository repo = FoodRepository(<FoodProvider>[
          const SampleFoodProvider(),
          CatalogueReleaseProvider(
            catalogueId: 'ift',
            readJson: () async {
              calls++;
              return calls == 1 ? '{not json' : jsonEncode(_release());
            },
          ),
        ]);

        await expectLater(
          repo.load(),
          throwsA(isA<CatalogueValidationException>()),
        );
        expect(repo.isLoaded, isFalse);

        await repo.load();
        expect(repo.isLoaded, isTrue);
        expect(repo.foodById('ift:test_egg'), isNotNull);
        expect(calls, 2);
      },
    );
  });

  group('Compatibility with calculation and logging', () {
    test('a catalogue food calculates like any other food', () {
      final Food egg = _parse(_release()).foods.single;
      final CalculatedNutrition result = NutritionEngine.calculate(
        food: egg,
        servingId: 'piece',
        quantity: 2,
      );
      // 2 pieces of 50 g is 100 g, so the per-100 g values come back as is.
      expect(result.totalMilligrams, 100000);
      expect(
        result.nutrients[NutrientKind.energy],
        const NutrientAmount.milli(150000),
      );
      expect(
        result.nutrients[NutrientKind.protein],
        const NutrientAmount.milli(12500),
      );
      expect(
        result.nutrients[NutrientKind.fat],
        const NutrientAmount.milli(10000),
      );
      expect(
        result.nutrients[NutrientKind.iron],
        const NutrientAmount.milli(1200),
      );
      expect(result.nutrients[NutrientKind.fibre], NutrientAmount.zero);
      expect(result.nutrients[NutrientKind.sugar], isNull);
      expect(result.isSample, isFalse);
      // The piece weight is documented as an estimate, so the result says so.
      expect(result.isEstimate, isTrue);
      expect(
        result.assumptions.any((String a) => a.contains('estimated')),
        isTrue,
      );
    });

    test('a logged catalogue food survives storage and validation', () {
      final Food egg = _parse(_release()).foods.single;
      final LogEntry entry = EntryBuilder.build(
        id: 'entry-1',
        date: LocalDate(2026, 10, 20),
        mealSlotId: 'breakfast',
        timestamp: DateTime(2026, 10, 20, 8),
        base: FoodPortion(food: egg, servingId: 'piece', quantity: 2),
      );
      expect(entry.base.dataStatus, DataStatus.verified);
      expect(entry.isSample, isFalse);

      final LogEntry restored = LogEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, Object?>,
      );
      expect(restored.base.dataStatus, DataStatus.verified);
      expect(
        restored.totals[NutrientKind.energy].amount,
        entry.totals[NutrientKind.energy].amount,
      );
      expect(restored.totals[NutrientKind.sugar].missingCount, 1);
    });
  });
}
