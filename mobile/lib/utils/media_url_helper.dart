import 'package:mobile/constants/api_endpoints.dart';

String? normalizeMediaUrl(String? value, {String? baseUrl}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }

  final backendUri = Uri.parse(baseUrl ?? ApiEndpoints.baseUrl);
  final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  final backendPath = backendUri.path.replaceFirst(RegExp(r'/+$'), '');
  if (backendPath.isNotEmpty &&
      (normalizedPath == backendPath ||
          normalizedPath.startsWith('$backendPath/'))) {
    return backendUri.replace(path: normalizedPath).toString();
  }

  return backendUri
      .replace(path: '$backendPath$normalizedPath', query: null, fragment: null)
      .toString();
}
