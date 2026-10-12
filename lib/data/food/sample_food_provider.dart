// SAMPLE FOOD DATA FOR DEVELOPMENT ONLY.
//
// Every number in this file is a rounded placeholder chosen to exercise the
// app. They are NOT real nutrition values and must never be shown without
// the "Sample" label. Real data arrives from licensed sources later.

import '../../domain/food/food.dart';
import '../../domain/food/serving.dart';
import '../../domain/nutrition/nutrition.dart';
import 'food_provider.dart';

final class SampleFoodProvider implements FoodProvider {
  const SampleFoodProvider();

  static const DataSourceInfo info = DataSourceInfo(
    id: 'sample',
    name: 'Sample data',
    licence: 'Development placeholders. Not real nutrition data.',
    isSample: true,
  );

  @override
  DataSourceInfo get source => info;

  @override
  Future<List<Food>> loadFoods() async => buildSampleFoods();
}

Serving _serving(String id, String singular, String plural, num grams) =>
    Serving(
      id: id,
      singularLabel: singular,
      pluralLabel: plural,
      grams: grams,
      weightBasis: ServingWeightBasis.estimated,
    );

NutrientProfile _profile({
  required num kcal,
  required num protein,
  required num carbs,
  required num fat,
  required num? fibre,
  required num? sugar,
  required num? sodium,
  num? iron,
  num? calcium,
  num? potassium,
}) => NutrientProfile.per100g(
  energyKcal: kcal,
  proteinG: protein,
  carbohydratesG: carbs,
  fatG: fat,
  fibreG: fibre,
  sugarG: sugar,
  sodiumMg: sodium,
  ironMg: iron,
  calciumMg: calcium,
  potassiumMg: potassium,
);

Food _food({
  required String id,
  required String name,
  List<String> aliases = const <String>[],
  required FoodCategory category,
  FoodRegion region = FoodRegion.panIndian,
  required NutrientProfile per100g,
  List<Serving> servings = const <Serving>[],
  String? family,
  String? variety,
  PreparationMethod? preparation,
  FoodState state = FoodState.ready,
}) => Food(
  id: 'sample:$id',
  name: name,
  aliases: aliases,
  category: category,
  region: region,
  per100g: per100g,
  servings: servings,
  status: DataStatus.sample,
  family: family,
  variety: variety,
  preparation: preparation,
  state: state,
);

/// The sample dataset. Covers varieties, raw/cooked records, household
/// servings, regional aliases, cooking fats and partly unknown nutrients.
List<Food> buildSampleFoods() => <Food>[
  // Chicken family: one record per variety and preparation.
  _food(
    id: 'chicken_breast_raw',
    name: 'Chicken breast, skinless, raw',
    aliases: const <String>['murgh breast'],
    category: FoodCategory.ingredient,
    family: 'Chicken',
    variety: 'Breast, skinless',
    preparation: PreparationMethod.raw,
    state: FoodState.raw,
    per100g: _profile(
      kcal: 120,
      protein: 22,
      carbs: 0,
      fat: 3,
      fibre: 0,
      sugar: 0,
      sodium: 60,
      iron: 0.5,
      potassium: 300,
    ),
  ),
  _food(
    id: 'chicken_breast_grilled',
    name: 'Chicken breast, skinless, grilled',
    category: FoodCategory.dish,
    family: 'Chicken',
    variety: 'Breast, skinless',
    preparation: PreparationMethod.grilled,
    state: FoodState.cooked,
    per100g: _profile(
      kcal: 160,
      protein: 30,
      carbs: 0,
      fat: 4,
      fibre: 0,
      sugar: 0,
      sodium: 70,
    ),
  ),
  _food(
    id: 'chicken_thigh_raw',
    name: 'Chicken thigh, skinless, raw',
    category: FoodCategory.ingredient,
    family: 'Chicken',
    variety: 'Thigh, skinless',
    preparation: PreparationMethod.raw,
    state: FoodState.raw,
    per100g: _profile(
      kcal: 140,
      protein: 19,
      carbs: 0,
      fat: 7,
      fibre: 0,
      sugar: 0,
      sodium: 90,
    ),
  ),
  _food(
    id: 'chicken_with_skin_raw',
    name: 'Chicken with skin, raw',
    category: FoodCategory.ingredient,
    family: 'Chicken',
    variety: 'With skin',
    preparation: PreparationMethod.raw,
    state: FoodState.raw,
    per100g: _profile(
      kcal: 220,
      protein: 18,
      carbs: 0,
      fat: 16,
      fibre: 0,
      sugar: 0,
      sodium: 70,
    ),
  ),

  // South Indian staples with household servings and regional names.
  _food(
    id: 'idli',
    name: 'Idli',
    aliases: const <String>['idly', 'iddli', 'idlis'],
    category: FoodCategory.dish,
    region: FoodRegion.southIndian,
    servings: <Serving>[_serving('piece', 'idli', 'idlis', 40)],
    per100g: _profile(
      kcal: 140,
      protein: 4,
      carbs: 30,
      fat: 0.5,
      fibre: 1,
      sugar: null,
      sodium: 250,
    ),
  ),
  _food(
    id: 'sambar',
    name: 'Sambar',
    aliases: const <String>['sambhar', 'saambar'],
    category: FoodCategory.curry,
    region: FoodRegion.southIndian,
    servings: <Serving>[_serving('bowl', 'bowl', 'bowls', 150)],
    per100g: _profile(
      kcal: 60,
      protein: 3,
      carbs: 8,
      fat: 2,
      fibre: 2,
      sugar: null,
      sodium: null,
    ),
  ),
  _food(
    id: 'rice_white_cooked',
    name: 'White rice, cooked',
    aliases: const <String>['chawal', 'sadam', 'annam', 'bhaat'],
    category: FoodCategory.rice,
    state: FoodState.cooked,
    preparation: PreparationMethod.boiled,
    servings: <Serving>[_serving('cup', 'cup', 'cups', 160)],
    per100g: _profile(
      kcal: 130,
      protein: 3,
      carbs: 28,
      fat: 0.5,
      fibre: 0.5,
      sugar: 0,
      sodium: 0,
    ),
  ),
  _food(
    id: 'chapati',
    name: 'Chapati',
    aliases: const <String>['roti', 'phulka', 'chapathi'],
    category: FoodCategory.bread,
    region: FoodRegion.northIndian,
    servings: <Serving>[_serving('piece', 'chapati', 'chapatis', 40)],
    per100g: _profile(
      kcal: 300,
      protein: 9,
      carbs: 50,
      fat: 7,
      fibre: 6,
      sugar: null,
      sodium: 300,
      iron: 3,
      calcium: 30,
    ),
  ),

  // Cooking fats and extras (used as add-ons in a later batch).
  _food(
    id: 'sunflower_oil',
    name: 'Sunflower oil',
    aliases: const <String>['cooking oil', 'refined oil'],
    category: FoodCategory.ingredient,
    servings: <Serving>[_serving('tsp', 'teaspoon', 'teaspoons', 5)],
    per100g: _profile(
      kcal: 900,
      protein: 0,
      carbs: 0,
      fat: 100,
      fibre: 0,
      sugar: 0,
      sodium: 0,
    ),
  ),
  _food(
    id: 'ghee',
    name: 'Ghee',
    aliases: const <String>['clarified butter', 'neyyi', 'tuppa'],
    category: FoodCategory.ingredient,
    servings: <Serving>[_serving('tsp', 'teaspoon', 'teaspoons', 5)],
    per100g: _profile(
      kcal: 900,
      protein: 0,
      carbs: 0,
      fat: 100,
      fibre: 0,
      sugar: 0,
      sodium: 0,
    ),
  ),
  _food(
    id: 'butter',
    name: 'Butter',
    aliases: const <String>['makhan'],
    category: FoodCategory.ingredient,
    servings: <Serving>[_serving('tsp', 'teaspoon', 'teaspoons', 5)],
    per100g: _profile(
      kcal: 720,
      protein: 1,
      carbs: 0,
      fat: 80,
      fibre: 0,
      sugar: 0,
      sodium: 600,
    ),
  ),
  _food(
    id: 'cream',
    name: 'Fresh cream',
    aliases: const <String>['malai'],
    category: FoodCategory.ingredient,
    servings: <Serving>[_serving('tbsp', 'tablespoon', 'tablespoons', 15)],
    per100g: _profile(
      kcal: 300,
      protein: 2,
      carbs: 3,
      fat: 30,
      fibre: 0,
      sugar: 3,
      sodium: 40,
    ),
  ),
];
