// lib/utils/search_tokens.dart

List<String> buildSearchTokens({
  required String serviceName,
  String? categoryName,
  Iterable<String>? subCategoryNames,
  String? description,
  int maxTokens = 50,
}) {
  final Set<String> tokens = <String>{};

  void addFrom(String? text) {
    if (text == null || text.trim().isEmpty) return;
    final matches = RegExp(r'[A-Za-z0-9]+').allMatches(text.toLowerCase());
    for (final m in matches) {
      final token = m.group(0);
      if (token == null || token.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(token)) continue;
      tokens.add(token);
      if (tokens.length >= maxTokens) return;
    }
  }

  addFrom(serviceName);
  addFrom(categoryName);
  if (subCategoryNames != null) {
    for (final name in subCategoryNames) {
      addFrom(name);
      if (tokens.length >= maxTokens) break;
    }
  }
  addFrom(description);

  final list = tokens.toList()..sort();
  return list;
}
