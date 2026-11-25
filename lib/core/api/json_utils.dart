Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is List) {
    return value.map(asMap).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

String? asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
  }
  return fallback;
}

DateTime? asDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// Converts any list into a list of non-empty strings.
List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    final text = asString(item);
    if (text != null) result.add(text);
  }
  return result;
}

/// Converts any map into a `Map<String, String>`, dropping null values.
Map<String, String> asStringMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  value.forEach((key, item) {
    final text = asString(item);
    if (text != null) result[key.toString()] = text;
  });
  return result;
}
