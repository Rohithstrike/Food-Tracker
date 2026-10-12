import 'package:flutter_test/flutter_test.dart';

import 'package:indian_food_tracker/data/food/food_provider.dart';
import 'package:indian_food_tracker/data/food/food_repository.dart';
import 'package:indian_food_tracker/data/food/food_search.dart';
import 'package:indian_food_tracker/data/food/sample_food_provider.dart';
import 'package:indian_food_tracker/domain/food/food.dart';
import 'package:indian_food_tracker/domain/food/serving.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition.dart';
import 'package:indian_food_tracker/domain/nutrition/nutrition_engine.dart';

// All foods and numbers here are SAMPLE data, not real nutrition values.

final class _FakeProvider implements FoodProvider {
  _FakeProvider(this.source, this.foods);

  @override
  final DataSourceInfo source;
  final List<Food> foods;
  int loadCount = 0;

  @override
  Future<List<Food>> loadFoods() async {
    loadCount++;
    return foods;
  }
}

Food _fakeFood(String id, {DataStatus status = DataStatus.userCustom}) => Food(
  id: id,
  name: 'Test food $id',
  category: FoodCategory.dish,
  region: FoodRegion.panIndian,
  status: status,
  per100g: NutrientProfile.per100g(
    energyKcal: 100,
    proteinG: null,
    carbohydratesG: null,
    fatG: null,
    fibreG: null,
    sugarG: null,
    sodiumMg: null,
  ),
);

const DataSourceInfo _testSource = DataSourceInfo(
  id: 'test',
  name: 'Test source',
  licence: 'Test only',
);

Future<FoodRepository> _sampleRepository() async {
  final FoodRepository repo = FoodRepository(const <FoodProvider>[
    SampleFoodProvider(),
  ]);
  await repo.load();
  return repo;
}

List<String> _names(List<FoodSearchResult> results) =>
    results.map((FoodSearchResult r) => r.food.name).toList();

void main() {
  group('Nutrient kinds', () {
    test('persisted names are stable (never rename or reorder)', () {
      expect(NutrientKind.values.map((NutrientKind k) => k.name).toList(), [
        'energy',
        'protein',
        'carbohydrates',
        'fat',
        'fibre',
        'sugar',
        'sodium',
        'iron',
        'calcium',
        'potassium',
        'magnesium',
        'zinc',
        'vitaminA',
        'vitaminC',
        'vitaminD',
        'vitaminB12',
        'folate',
      ]);
    });

    test('core seven are the original nutrients', () {
      expect(NutrientKind.values.where((NutrientKind k) => k.isCore).toSet(), {
        NutrientKind.energy,
        NutrientKind.protein,
        NutrientKind.carbohydrates,
        NutrientKind.fat,
        NutrientKind.fibre,
        NutrientKind.sugar,
        NutrientKind.sodium,
      });
      expect(NutrientKind.vitaminB12.unit, '\u00B5g');
      expect(NutrientKind.iron.group, NutrientGroup.mineral);
    });

    test('micronutrients scale through the existing engine', () {
      final Food food = Food(
        id: 'test:iron',
        name: 'SAMPLE iron food',
        category: FoodCategory.dish,
        region: FoodRegion.panIndian,
        status: DataStatus.sample,
        per100g: NutrientProfile.per100g(
          energyKcal: 100,
          proteinG: 1,
          carbohydratesG: 1,
          fatG: 1,
          fibreG: 1,
          sugarG: 1,
          sodiumMg: 1,
          ironMg: 2.5,
          vitaminB12Ug: 0,
        ),
      );
      final CalculatedNutrition r = NutritionEngine.calculate(
        food: food,
        servingId: Serving.gramId,
        quantity: 40,
      );
      // 2.5 mg per 100 g x 40 g = 1 mg.
      expect(r.nutrients[NutrientKind.iron], const NutrientAmount.milli(1000));
      // A known zero stays zero; an unsupplied micronutrient stays unknown.
      expect(r.nutrients[NutrientKind.vitaminB12], NutrientAmount.zero);
      expect(r.nutrients[NutrientKind.calcium], isNull);
    });

    test('totals count items missing a micronutrient', () {
      final List<Food> foods = buildSampleFoods();
      final Food chapati = foods.firstWhere(
        (Food f) => f.id == 'sample:chapati',
      );
      final Food idli = foods.firstWhere((Food f) => f.id == 'sample:idli');
      final NutritionTotals totals = NutritionEngine.total(
        <CalculatedNutrition>[
          NutritionEngine.calculate(
            food: chapati,
            servingId: 'piece',
            quantity: 1,
          ),
          NutritionEngine.calculate(
            food: idli,
            servingId: 'piece',
            quantity: 2,
          ),
        ],
      );
      // Chapati has iron (3 mg/100 g x 40 g = 1.2 mg); idli has none listed.
      expect(
        totals[NutrientKind.iron].amount,
        const NutrientAmount.milli(1200),
      );
      expect(totals[NutrientKind.iron].missingCount, 1);
      expect(totals.isSample, isTrue);
    });
  });

  group('Sample provider', () {
    test('every food is sample data with a prefixed, unique id', () {
      final List<Food> foods = buildSampleFoods();
      expect(foods, isNotEmpty);
      expect(foods.every((Food f) => f.isSample), isTrue);
      expect(foods.every((Food f) => f.id.startsWith('sample:')), isTrue);
      expect(foods.map((Food f) => f.id).toSet().length, foods.length);
      expect(SampleFoodProvider.info.isSample, isTrue);
    });

    test('every sample food calculates for 100 g', () {
      for (final Food food in buildSampleFoods()) {
        final CalculatedNutrition r = NutritionEngine.calculate(
          food: food,
          servingId: Serving.gramId,
          quantity: 100,
        );
        expect(r.isSample, isTrue, reason: food.id);
        expect(r.nutrients[NutrientKind.energy], isNotNull, reason: food.id);
      }
    });

    test('raw and cooked records declare their state', () {
      final List<Food> foods = buildSampleFoods();
      Food byId(String id) => foods.firstWhere((Food f) => f.id == id);
      expect(byId('sample:chicken_breast_raw').state, FoodState.raw);
      expect(byId('sample:chicken_breast_grilled').state, FoodState.cooked);
      expect(
        byId('sample:chicken_breast_grilled').preparation,
        PreparationMethod.grilled,
      );
    });
  });

  group('Search', () {
    test('normalisation ignores case, punctuation and extra spaces', () {
      expect(normaliseSearchText('  CHICKEN,   breast!! '), 'chicken breast');
      expect(normaliseSearchText('---'), '');
    });

    test('regional names and spellings find the food', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(repo.search('idly').first.food.id, 'sample:idli');
      expect(repo.search('roti').first.food.id, 'sample:chapati');
      expect(repo.search('chawal').first.food.id, 'sample:rice_white_cooked');
      expect(repo.search('sambhar').first.food.id, 'sample:sambar');
    });

    test('an exact name ranks first', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(repo.search('Ghee').first.food.id, 'sample:ghee');
    });

    test('multi-word queries match the right variety', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(_names(repo.search('  CHICKEN   breast ')), [
        'Chicken breast, skinless, raw',
        'Chicken breast, skinless, grilled',
      ]);
    });

    test('a prefix finds every variety in the family', () async {
      final FoodRepository repo = await _sampleRepository();
      final List<FoodSearchResult> results = repo.search('chick');
      expect(results.length, 4);
      expect(
        results.every((FoodSearchResult r) => r.food.family == 'Chicken'),
        isTrue,
      );
    });

    test('empty, whitespace and no-match queries return nothing', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(repo.search(''), isEmpty);
      expect(repo.search('   '), isEmpty);
      expect(repo.search('zzzz'), isEmpty);
    });

    test('limit is respected', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(repo.search('chick', limit: 2).length, 2);
      expect(repo.search('chick', limit: 0), isEmpty);
    });

    test('results carry their data source', () async {
      final FoodRepository repo = await _sampleRepository();
      final FoodSearchResult r = repo.search('idli').first;
      expect(r.source.id, 'sample');
      expect(r.source.isSample, isTrue);
    });
  });

  group('Repository', () {
    test('lookups and family listing', () async {
      final FoodRepository repo = await _sampleRepository();
      expect(repo.foodCount, buildSampleFoods().length);
      expect(repo.foodById('sample:ghee')?.name, 'Ghee');
      expect(repo.foodById('sample:missing'), isNull);
      expect(repo.sourceOf('sample:ghee')?.id, 'sample');
      expect(repo.varietiesOf('chicken').length, 4);
      expect(repo.varietiesOf('Unknown family'), isEmpty);
    });

    test('using the repository before load fails clearly', () {
      final FoodRepository repo = FoodRepository(const <FoodProvider>[
        SampleFoodProvider(),
      ]);
      expect(() => repo.search('idli'), throwsStateError);
      expect(() => repo.foodById('sample:idli'), throwsStateError);
    });

    test('load runs each provider only once', () async {
      final _FakeProvider provider = _FakeProvider(_testSource, <Food>[
        _fakeFood('test:a'),
      ]);
      final FoodRepository repo = FoodRepository(<FoodProvider>[provider]);
      await Future.wait(<Future<void>>[repo.load(), repo.load()]);
      await repo.load();
      expect(provider.loadCount, 1);
      expect(repo.isLoaded, isTrue);
    });

    test('duplicate source ids are rejected', () async {
      const DataSourceInfo other = DataSourceInfo(
        id: 'test',
        name: 'Second source with the same id',
        licence: 'Test only',
      );
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(_testSource, <Food>[_fakeFood('test:a')]),
        _FakeProvider(other, <Food>[_fakeFood('test:b')]),
      ]);
      await expectLater(repo.load(), throwsStateError);
    });

    test('duplicate food ids are rejected', () async {
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(_testSource, <Food>[
          _fakeFood('test:a'),
          _fakeFood('test:a'),
        ]),
      ]);
      await expectLater(repo.load(), throwsStateError);
    });

    test('ids must carry their source prefix', () async {
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(_testSource, <Food>[_fakeFood('wrong:a')]),
      ]);
      await expectLater(repo.load(), throwsStateError);
    });

    test('a sample source cannot contain non-sample foods', () async {
      const DataSourceInfo sampleSource = DataSourceInfo(
        id: 'test',
        name: 'Sample source',
        licence: 'Test only',
        isSample: true,
      );
      final FoodRepository repo = FoodRepository(<FoodProvider>[
        _FakeProvider(sampleSource, <Food>[_fakeFood('test:a')]),
      ]);
      await expectLater(repo.load(), throwsStateError);
    });
  });
}
