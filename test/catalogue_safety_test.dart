import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/food_provider.dart';
import 'package:indian_food_tracker/data/food/food_repository.dart';
import 'package:indian_food_tracker/data/food/food_search.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';

// Catalogue safety: Tamil-aware search normalisation and atomic repository
// loading. Foods here are TEST fixtures with placeholder nutrition values.
// All Tamil text is written as Unicode escapes so the file is encoding-safe.

// Tamil "dosai" (dosa).
const String tamilDosai = '\u0BA4\u0BCB\u0B9A\u0BC8';

// A DIFFERENT word that differs only by one vowel sign. Before this fix,
// vowel signs were deleted, so it normalised to the same fragments as
// tamilDosai.
const String tamilOtherWord = '\u0BA4\u0BC7\u0B9A\u0BC8';

// Tamil "idli".
const String tamilIdli = '\u0B87\u0B9F\u0BCD\u0BB2\u0BBF';

NutrientProfile _profile() => NutrientProfile.per100g(
  energyKcal: 100,
  proteinG: null,
  carbohydratesG: null,
  fatG: null,
  fibreG: null,
  sugarG: null,
  sodiumMg: null,
);

Food _food(String id, String name, {List<String> aliases = const <String>[]}) =>
    Food(
      id: id,
      name: name,
      aliases: aliases,
      category: FoodCategory.dish,
      region: FoodRegion.southIndian,
      per100g: _profile(),
      status: DataStatus.userCustom,
    );

DataSourceInfo _source(String id) =>
    DataSourceInfo(id: id, name: 'Test $id', licence: 'Test only');

final class _FakeProvider implements FoodProvider {
  _FakeProvider(this.source, this._load);

  @override
  final DataSourceInfo source;

  final Future<List<Food>> Function(int call) _load;
  int calls = 0;

  @override
  Future<List<Food>> loadFoods() {
    calls++;
    return _load(calls);
  }
}

void main() {
  group('Search normalisation', () {
    test('keeps Tamil vowel signs and the pulli intact', () {
      expect(normaliseSearchText(tamilDosai), tamilDosai);
      expect(normaliseSearchText(tamilIdli), tamilIdli);
      expect(
        normaliseSearchText('  $tamilDosai,  $tamilIdli! '),
        '$tamilDosai $tamilIdli',
      );
    });

    test('different Tamil words stay different', () {
      expect(
        normaliseSearchText(tamilDosai),
        isNot(normaliseSearchText(tamilOtherWord)),
      );
    });

    test('English and digit behaviour is unchanged', () {
      expect(normaliseSearchText('  CHICKEN,   breast!! '), 'chicken breast');
      expect(normaliseSearchText('---'), '');
      expect(normaliseSearchText(''), '');
      expect(normaliseSearchText('Idli #2'), 'idli 2');
    });

    test('invisible joiners are removed, not treated as separators', () {
      expect(normaliseSearchText('do\u200Dsa'), 'dosa');
      expect(normaliseSearchText('do\u200Csa'), 'dosa');
      expect(normaliseSearchText('\uFEFFdosa'), 'dosa');
    });
  });

  group('Tamil search', () {
    final List<Food> foods = <Food>[
      _food('t:dosa', 'Dosa', aliases: <String>['dosai', tamilDosai]),
      _food('t:other', 'Other sample', aliases: <String>[tamilOtherWord]),
      _food('t:idli', 'Idli', aliases: <String>[tamilIdli]),
    ];
    final FoodSearchIndex index = FoodSearchIndex(foods);

    List<String> ids(String query) =>
        index.search(query).map((Food f) => f.id).toList();

    test('finds a food by its Tamil alias', () {
      expect(ids(tamilDosai), <String>['t:dosa']);
      expect(ids(tamilIdli), <String>['t:idli']);
    });

    test('a Tamil word no longer matches a different Tamil word', () {
      expect(ids(tamilDosai), isNot(contains('t:other')));
      expect(ids(tamilOtherWord), <String>['t:other']);
    });

    test('a Tamil prefix finds the word it starts', () {
      // First consonant plus the vowel sign: a prefix of tamilDosai only.
      expect(ids('\u0BA4\u0BCB'), <String>['t:dosa']);
    });

    test('English search and ranking still work', () {
      expect(ids('dosa'), <String>['t:dosa']);
      expect(ids('IDLI'), <String>['t:idli']);
      expect(ids('zzz'), isEmpty);
    });
  });

  group('Atomic catalogue loading', () {
    test('a failed load publishes nothing', () async {
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(_source('a'), (int _) async => <Food>[_food('a:1', 'A')]),
        // Second provider returns the same id twice: validation fails AFTER
        // the first provider has already been read successfully.
        _FakeProvider(
          _source('b'),
          (int _) async => <Food>[_food('b:1', 'B'), _food('b:1', 'B again')],
        ),
      ]);

      await expectLater(repo.load(), throwsStateError);

      expect(repo.isLoaded, isFalse);
      expect(() => repo.foodCount, throwsStateError);
      expect(() => repo.foodById('a:1'), throwsStateError);
      expect(() => repo.search('A'), throwsStateError);
    });

    test('a failed load can be retried and then succeeds', () async {
      final _FakeProvider provider = _FakeProvider(_source('a'), (
        int call,
      ) async {
        if (call == 1) {
          throw StateError('temporary failure');
        }
        return <Food>[_food('a:1', 'Idli')];
      });
      final FoodRepository repo = FoodRepository(<FoodProvider>[provider]);

      await expectLater(repo.load(), throwsStateError);
      expect(repo.isLoaded, isFalse);

      await repo.load();
      expect(repo.isLoaded, isTrue);
      expect(repo.foodCount, 1);
      expect(repo.foodById('a:1')?.name, 'Idli');
      expect(provider.calls, 2);
    });

    test(
      'a retry does not report duplicates from the failed attempt',
      () async {
        int attempt = 0;
        final FoodRepository repo = FoodRepository(<FoodProvider>[
          _FakeProvider(
            _source('a'),
            (int _) async => <Food>[_food('a:1', 'A')],
          ),
          _FakeProvider(_source('b'), (int _) async {
            attempt++;
            if (attempt == 1) {
              throw StateError('second provider fails once');
            }
            return <Food>[_food('b:1', 'B')];
          }),
        ]);

        await expectLater(repo.load(), throwsStateError);
        // If the first attempt had left 'a:1' behind, this retry would fail
        // with "Duplicate food id: a:1".
        await repo.load();
        expect(repo.foodCount, 2);
      },
    );

    test('concurrent loads share one attempt', () async {
      final _FakeProvider provider = _FakeProvider(
        _source('a'),
        (int _) async => <Food>[_food('a:1', 'A')],
      );
      final FoodRepository repo = FoodRepository(<FoodProvider>[provider]);

      await Future.wait(<Future<void>>[repo.load(), repo.load()]);
      expect(provider.calls, 1);
      expect(repo.foodCount, 1);
    });

    test(
      'concurrent loads fail together, then a later load can succeed',
      () async {
        final _FakeProvider provider = _FakeProvider(_source('a'), (
          int call,
        ) async {
          if (call == 1) {
            throw StateError('first attempt fails');
          }
          return <Food>[_food('a:1', 'A')];
        });
        final FoodRepository repo = FoodRepository(<FoodProvider>[provider]);

        final Future<void> first = repo.load();
        final Future<void> second = repo.load();
        await expectLater(first, throwsStateError);
        await expectLater(second, throwsStateError);
        expect(provider.calls, 1);

        await repo.load();
        expect(repo.isLoaded, isTrue);
        expect(provider.calls, 2);
      },
    );

    test('a successful load is not repeated', () async {
      final _FakeProvider provider = _FakeProvider(
        _source('a'),
        (int _) async => <Food>[_food('a:1', 'A')],
      );
      final FoodRepository repo = FoodRepository(<FoodProvider>[provider]);

      await repo.load();
      await repo.load();
      expect(provider.calls, 1);
    });

    test('validation rules are unchanged', () async {
      // Wrong id prefix.
      await expectLater(
        FoodRepository(<FoodProvider>[
          _FakeProvider(
            _source('a'),
            (int _) async => <Food>[_food('x:1', 'A')],
          ),
        ]).load(),
        throwsStateError,
      );
      // Duplicate source ids.
      await expectLater(
        FoodRepository(<FoodProvider>[
          _FakeProvider(
            _source('a'),
            (int _) async => <Food>[_food('a:1', 'A')],
          ),
          _FakeProvider(
            _source('a'),
            (int _) async => <Food>[_food('a:2', 'B')],
          ),
        ]).load(),
        throwsStateError,
      );
      // A sample source may only contain sample foods.
      await expectLater(
        FoodRepository(<FoodProvider>[
          _FakeProvider(
            const DataSourceInfo(
              id: 's',
              name: 'Sample',
              licence: 'Test only',
              isSample: true,
            ),
            (int _) async => <Food>[_food('s:1', 'A')],
          ),
        ]).load(),
        throwsStateError,
      );
    });

    test('lookups work after a successful load', () async {
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(
          _source('a'),
          (int _) async => <Food>[
            _food('a:1', 'Idli', aliases: <String>[tamilIdli]),
          ],
        ),
      ]);
      await repo.load();

      expect(repo.search(tamilIdli).single.food.id, 'a:1');
      expect(repo.search('idli').single.source.id, 'a');
      expect(repo.sourceOf('a:1')?.id, 'a');
      expect(repo.foodById('a:missing'), isNull);
    });
  });
}
