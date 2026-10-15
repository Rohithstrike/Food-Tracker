// Offline food provider for a validated catalogue release.
//
// The provider reads the release text through a loader function (a bundled
// asset, a downloaded file, or a test string), validates it with
// CatalogueRelease, and hands the foods to the FoodRepository. Because
// validation happens inside loadFoods, an invalid release makes the
// repository's atomic load fail: nothing from it ever reaches search, and the
// next load starts a fresh attempt.

import '../../domain/food/food.dart';
import 'catalogue_release.dart';
import 'food_provider.dart';

final class CatalogueReleaseProvider implements FoodProvider {
  /// [catalogueId] must match the release's own catalogue id; food ids are
  /// prefixed with it. [readJson] returns the release text.
  CatalogueReleaseProvider({
    required String catalogueId,
    required this._readJson,
    String name = 'Food catalogue',
  }) : source = _sourceFor(catalogueId, name);

  final Future<String> Function() _readJson;
  CatalogueRelease? _release;

  @override
  final DataSourceInfo source;

  /// The validated release from the last successful load, or null before a
  /// load has succeeded. Use it to show attribution and release details.
  CatalogueRelease? get release => _release;

  @override
  Future<List<Food>> loadFoods() async {
    final String text = await _readJson();
    final CatalogueRelease parsed = CatalogueRelease.parse(text);
    if (parsed.catalogueId != source.id) {
      throw CatalogueValidationException(<CatalogueIssue>[
        CatalogueIssue(
          'catalogueId',
          'is "${parsed.catalogueId}", but this provider serves "${source.id}"',
        ),
      ]);
    }
    _release = parsed;
    return parsed.foods;
  }

  static DataSourceInfo _sourceFor(String catalogueId, String name) {
    if (!CatalogueRelease.isValidCatalogueId(catalogueId)) {
      throw ArgumentError.value(
        catalogueId,
        'catalogueId',
        'must be 2 to 16 lowercase letters or digits, starting with a '
            'letter, and must not be reserved',
      );
    }
    return DataSourceInfo(
      id: catalogueId,
      name: name,
      licence:
          'Each upstream source and its licence are recorded in the '
          'catalogue release.',
    );
  }
}
