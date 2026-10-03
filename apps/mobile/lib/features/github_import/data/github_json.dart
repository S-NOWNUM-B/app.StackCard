Map<String, dynamic> githubObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Ожидался JSON object');
  }
  return value;
}

String githubString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Некорректное поле $key');
  }
  return value;
}

String? githubOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Некорректное поле $key');
  return value;
}

int githubInteger(Map<String, dynamic> json, String key, {int minimum = 0}) {
  final value = json[key];
  if (value is! int || value < minimum) {
    throw FormatException('Некорректное поле $key');
  }
  return value;
}

bool githubBoolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Некорректное поле $key');
  return value;
}

String githubUrl(Map<String, dynamic> json, String key) {
  final value = githubString(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw FormatException('Некорректный URL $key');
  }
  return value;
}
