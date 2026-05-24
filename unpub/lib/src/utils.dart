import 'package:yaml/yaml.dart';

dynamic convertYaml(dynamic value) {
  if (value is YamlMap) {
    return value
        .cast<String, dynamic>()
        .map((k, v) => MapEntry(k, convertYaml(v)));
  }
  if (value is YamlList) {
    return value.map(convertYaml).toList();
  }
  return value;
}

Map<String, dynamic>? loadYamlAsMap(dynamic value) {
  final yamlMap = loadYaml(value);
  if (yamlMap is! YamlMap) {
    return null;
  }
  final converted = convertYaml(yamlMap);
  if (converted is! Map) {
    return null;
  }
  return converted.cast<String, dynamic>();
}

List<String> getPackageTags(Map<String, dynamic> pubspec) {
  // TODO: web and other tags
  if (pubspec['flutter'] != null) {
    return ['flutter'];
  } else {
    return ['flutter', 'web', 'other'];
  }
}
