import '../database/database.dart';

/// Normalizes text for fuzzy Arabic/Latin product search.
String normalizeSearchText(String input) {
  var s = input.trim().toLowerCase();
  const replacements = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ى': 'ي',
    'ة': 'ه',
    'ؤ': 'و',
    'ئ': 'ي',
  };
  for (final entry in replacements.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }
  s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

List<String> searchTokens(String query) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ').where((t) => t.isNotEmpty).toList();
}

int scoreProductMatch(Product product, String query) {
  final tokens = searchTokens(query);
  if (tokens.isEmpty) return 0;

  final barcode = product.barcode?.trim() ?? '';
  final sku = product.sku?.trim() ?? '';
  final rawQuery = query.trim();

  if (barcode.isNotEmpty &&
      (barcode == rawQuery || barcode.contains(rawQuery))) {
    return 1000;
  }
  if (sku.isNotEmpty && (sku == rawQuery || sku.contains(rawQuery))) {
    return 950;
  }

  final nameAr = normalizeSearchText(product.nameAr);
  final nameEn = normalizeSearchText(product.nameEn ?? '');

  if (nameAr == normalizeSearchText(rawQuery) ||
      nameEn == normalizeSearchText(rawQuery)) {
    return 900;
  }

  if (nameAr.startsWith(tokens.first) || nameEn.startsWith(tokens.first)) {
    return 800;
  }

  final allInAr = tokens.every(nameAr.contains);
  final allInEn = nameEn.isNotEmpty && tokens.every(nameEn.contains);
  if (allInAr || allInEn) {
    return 600 + tokens.length * 10;
  }

  var partial = 0;
  for (final token in tokens) {
    if (nameAr.contains(token) || nameEn.contains(token)) {
      partial += 100;
    }
  }
  return partial;
}

List<Product> rankProductsBySearch({
  required List<Product> products,
  required String query,
  int? categoryId,
}) {
  final tokens = searchTokens(query);
  final filtered = products.where((product) {
    if (categoryId != null && product.categoryId != categoryId) {
      return false;
    }
    if (tokens.isEmpty) return true;
    return scoreProductMatch(product, query) > 0;
  }).toList();

  if (tokens.isEmpty) return filtered;

  filtered.sort((a, b) {
    final scoreDiff = scoreProductMatch(b, query) - scoreProductMatch(a, query);
    if (scoreDiff != 0) return scoreDiff;
    return a.nameAr.compareTo(b.nameAr);
  });
  return filtered;
}
