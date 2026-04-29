Uri buildWmsUri({
  required Uri base,
  required Map<String, String> params,
}) {
  final pairs = <String>[];
  for (final entry in params.entries) {
    final encodedValue =
        Uri.encodeQueryComponent(entry.value).replaceAll('%2F', '/');
    pairs.add('${entry.key}=$encodedValue');
  }
  return base.replace(query: pairs.join('&'));
}
