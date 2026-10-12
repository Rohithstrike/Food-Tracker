# Data model and persistence plan

Status: Batch 1 (data foundations). Persistence is implemented in Batch 5,
but the models below are designed for it now so logging is not redesigned.

## Layers

```
UI (Today, Search, Food detail)
  -> FoodRepository            lib/data/food/food_repository.dart
       -> FoodProvider(s)      lib/data/food/food_provider.dart
            SampleFoodProvider (now, clearly marked sample data)
            Bundled USDA subset (Batch 6)
            Curated Indian layer + recipes (Batch 6)
            Packaged foods / Open Food Facts (V2, after licence review)
  -> NutritionEngine           the ONLY place nutrition is calculated
  -> LogStore (Batch 5)        saved entries and history
```

Rules:
- Food ids are `<sourceId>:<localId>` and must be unique across sources.
- The UI depends on FoodRepository only. Adding or replacing a source means
  adding a provider; screens do not change.
- Online sources (if ever added) get their own interface and are merged by
  the repository. No API key is ever shipped inside the app.

## Data sources and licensing

| Source | Use | Licence / conditions | Status |
|---|---|---|---|
| Sample provider | Development | Placeholders, NOT real data; always labelled "Sample" | In app |
| USDA FoodData Central | Standard ingredients | Public domain. API key must stay private; bundle a converted subset instead of calling the API from the app | Planned (Batch 6) |
| Open Food Facts | Packaged foods (V2) | ODbL: attribution on store page, in app screens and legal page; share-alike for adapted databases. Crowdsourced, no accuracy guarantee | Evaluate before use |
| IFCT 2017 (NIN) | Indian foods | Electronic storage for a product requires NIN's prior written permission | NOT used until permission is confirmed |

Every imported dataset must record: source, version/date, licence, the
original record id (`FoodSource.recordId`) and any required attribution.

## Food model (implemented)

- `Food`: id, name, aliases (regional names, spellings), category, region,
  `family` (e.g. Chicken) and `variety` (e.g. Breast, skinless),
  `preparation` (boiled, grilled, ...), `state` (raw / cooked / ready),
  per-100 g `NutrientProfile`, servings, `DataStatus`, `FoodSource`.
- Varieties and preparations are separate records where a source has them,
  so values stay source-backed rather than adjusted.
- `NutrientKind`: core seven + iron, calcium, potassium, magnesium, zinc,
  vitamins A, C, D, B12, folate. Unknown values are absent, never zero.
  Enum NAMES are a persistence contract: never rename or reorder.

## Logged entry model (designed now, built in Batch 2)

One logged entry = a base food + optional added oil + optional extras.
Each component is calculated by `NutritionEngine.calculate`; the entry total
is `NutritionEngine.total` of its components.

```
LogEntry
  id, date (local yyyy-mm-dd), mealSlotId (stable id, e.g. "lunch"),
  createdAt, updatedAt
  components: List<EntryComponent>
  snapshot: per-nutrient totals + missing counts (frozen at log time)
  isSample, isEstimate, assumptions

EntryComponent
  role: base | oil | extra
  foodId, foodName, sourceId          (copied, for history)
  servingId, servingGrams, quantity   (copied)
  weightState: raw | cooked           (what the user weighed)
  yieldFactor (if raw<->cooked converted; always an estimate)
  calculated nutrients (snapshot)
```

Snapshots mean later dataset corrections never silently change past days.
Meal slots are referenced by id, so renaming or hiding a slot keeps history.

## Cooking, oil and recipes

- Preparation: prefer a source record for the cooked food. Otherwise raw
  food x documented cooking yield, labelled as an estimate.
- Oil: added as grams of an oil food. None / Very little / Normal / High map
  to documented default grams that the user can edit. Always an estimate.
- Extras (butter, ghee, cream, sauces): separate components with grams.
- "Lightly / heavily cooked": no numeric effect without a documented basis.
- Recipes: ingredients (raw weights) + finished cooked weight + servings ->
  per-100 g profile computed with the engine, stored as `recipeEstimate`.

## Persistence recommendation

- Settings (theme, goals): `shared_preferences` - small key/value data only.
- Food log and history: **SQLite**, recommended via the `drift` package:
  typed tables, queries by date and meal, transactions, and schema
  migrations as the app grows. `shared_preferences` is not suitable for
  structured, growing history.
- Web (Chrome development) needs drift's web setup (sqlite3 WASM files in
  `web/`). This must be verified in Batch 5 before relying on it.
- Packages require approval before they are added (Batch 5).
- Cloud sync: not planned for V1.

Proposed tables: `log_entries`, `entry_components`,
`entry_component_nutrients` (componentId, nutrient name, milli value).
Unknown nutrients have no row. Missing counts are recomputed from rows.
