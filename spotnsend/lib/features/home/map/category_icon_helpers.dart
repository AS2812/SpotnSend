import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Mapping of canonical category slugs to their asset icon paths.
const Map<String, String> categoryIconBySlug = {
  'ROAD_TRAFFIC': 'assets/category_icons/ROAD_TRAFFIC.png',
  'ROADWAY_HAZARD': 'assets/category_icons/ROADWAY_HAZARD.png',
  'FIRE_EXPLOSION': 'assets/category_icons/FIRE_&_EXPLOSION.png',
  'BUILDING_INFRA': 'assets/category_icons/BUILDING_&INFRASTRUCTURE.png',
  'RAIL_PUBLIC_TRANSPORT': 'assets/category_icons/RAIL_&_PUBLIC_TRANSPORT.png',
  'UTILITIES': 'assets/category_icons/UTILITIES.png',
  'ENV_WEATHER': 'assets/category_icons/ENVIRONMENT_&_WEATHER.png',
  'MEDICAL_EMERGENCY': 'assets/category_icons/MEDICAL_EMERGENCY.png',
  'OCCUPATIONAL_INDUSTRIAL': 'assets/category_icons/OCCUPATIONAL_&_INDUSTRIAL.png',
  'PUBLIC_SAFETY_CRIME': 'assets/category_icons/PUBLIC_SAFETY_&_CRIME.png',
  'MARINE_WATERWAY': 'assets/category_icons/MARINE_&_WATERWAY.png',
};

/// Alternative keys that should resolve to the canonical slug.
const Map<String, String> _categorySlugSynonyms = {
  'ROAD_TRAFFIC': 'ROAD_TRAFFIC',
  'TRAFFIC': 'ROAD_TRAFFIC',
  'ROADWAY_HAZARD': 'ROADWAY_HAZARD',
  'ROAD_HAZARD': 'ROADWAY_HAZARD',
  'FIRE_EXPLOSION': 'FIRE_EXPLOSION',
  'FIRE_AND_EXPLOSION': 'FIRE_EXPLOSION',
  'BUILDING_INFRA': 'BUILDING_INFRA',
  'BUILDING_INFRASTRUCTURE': 'BUILDING_INFRA',
  'BUILDING_AND_INFRASTRUCTURE': 'BUILDING_INFRA',
  'RAIL_PUBLIC_TRANSPORT': 'RAIL_PUBLIC_TRANSPORT',
  'PUBLIC_TRANSPORT': 'RAIL_PUBLIC_TRANSPORT',
  'RAIL_AND_PUBLIC_TRANSPORT': 'RAIL_PUBLIC_TRANSPORT',
  'UTILITIES': 'UTILITIES',
  'ENV_WEATHER': 'ENV_WEATHER',
  'ENVIRONMENT_WEATHER': 'ENV_WEATHER',
  'ENVIRONMENTAL_WEATHER': 'ENV_WEATHER',
  'ENVIRONMENT_AND_WEATHER': 'ENV_WEATHER',
  'MEDICAL_EMERGENCY': 'MEDICAL_EMERGENCY',
  'MEDICAL': 'MEDICAL_EMERGENCY',
  'OCCUPATIONAL_INDUSTRIAL': 'OCCUPATIONAL_INDUSTRIAL',
  'INDUSTRIAL': 'OCCUPATIONAL_INDUSTRIAL',
  'PUBLIC_SAFETY_CRIME': 'PUBLIC_SAFETY_CRIME',
  'PUBLIC_SAFETY_AND_CRIME': 'PUBLIC_SAFETY_CRIME',
  'MARINE_WATERWAY': 'MARINE_WATERWAY',
  'MARINE_AND_WATERWAY': 'MARINE_WATERWAY',
};

String _normalizeCategoryKey(String value) {
  final cleaned = value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp('_+'), '_');
  return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Returns a canonical slug for the provided [value], or null if it can't be
/// resolved to one of the supported icon categories.
String? resolveCategorySlug(String? value) {
  if (value == null || value.isEmpty) return null;
  final key = _normalizeCategoryKey(value);
  if (categoryIconBySlug.containsKey(key)) return key;
  return _categorySlugSynonyms[key];
}

String canonicalizeSlug(String slug) => _normalizeCategoryKey(slug);

/// Returns the asset path for a given slug, or null if none exists.
String? iconAssetForSlug(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  final canonical = canonicalizeSlug(slug);
  return categoryIconBySlug[canonical];
}

/// Returns the asset path for a given human-readable category name.
String? iconAssetForCategoryName(String? categoryName) {
  if (categoryName == null || categoryName.isEmpty) return null;
  final slug = resolveCategorySlug(categoryName);
  return iconAssetForSlug(slug);
}

/// MapLibre image key for a slug (used when registering as map symbols).
String? mapImageKeyForSlug(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  final canonical = canonicalizeSlug(slug);
  if (!categoryIconBySlug.containsKey(canonical)) return null;
  return 'category-$canonical';
}

String? mapImageKeyForCategoryName(String? categoryName) {
  final slug = resolveCategorySlug(categoryName);
  return mapImageKeyForSlug(slug);
}

Future<void> registerCategoryIcons(MaplibreMapController controller) async {
  Future<void> register(String key, String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      await controller.addImage(key, bytes.buffer.asUint8List());
    } catch (err) {
      // Silently ignore missing assets; MapLibre will fall back to default pins.
    }
  }

  for (final entry in categoryIconBySlug.entries) {
    final key = mapImageKeyForSlug(entry.key);
    if (key != null) {
      await register(key, entry.value);
    }
  }
}
