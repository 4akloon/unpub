import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@JsonSerializable()
class ListApi {
  const ListApi(this.count, this.packages);

  final int count;
  final List<ListApiPackage> packages;

  factory ListApi.fromJson(Map<String, dynamic> map) => _$ListApiFromJson(map);
  Map<String, dynamic> toJson() => _$ListApiToJson(this);
}

@JsonSerializable()
class ListApiPackage {
  const ListApiPackage(this.name, this.description, this.tags, this.latest, this.updatedAt);

  final String name;
  final String? description;
  final List<String> tags;
  final String latest;
  final DateTime updatedAt;

  factory ListApiPackage.fromJson(Map<String, dynamic> map) => _$ListApiPackageFromJson(map);
  Map<String, dynamic> toJson() => _$ListApiPackageToJson(this);
}

@JsonSerializable()
class DetailViewVersion {
  const DetailViewVersion(this.version, this.createdAt);

  final String version;
  final DateTime createdAt;

  factory DetailViewVersion.fromJson(Map<String, dynamic> map) => _$DetailViewVersionFromJson(map);

  Map<String, dynamic> toJson() => _$DetailViewVersionToJson(this);
}

@JsonSerializable()
class WebapiDetailView {
  const WebapiDetailView(
    this.name,
    this.version,
    this.description,
    this.homepage,
    this.uploaders,
    this.createdAt,
    this.readme,
    this.changelog,
    this.versions,
    this.authors,
    this.dependencies,
    this.tags,
  );

  final String name;
  final String version;
  final String description;
  final String homepage;
  final List<String> uploaders;
  final DateTime createdAt;
  final String? readme;
  final String? changelog;
  final List<DetailViewVersion> versions;
  final List<String?> authors;
  final List<String>? dependencies;
  final List<String> tags;

  factory WebapiDetailView.fromJson(Map<String, dynamic> map) => _$WebapiDetailViewFromJson(map);

  Map<String, dynamic> toJson() => _$WebapiDetailViewToJson(this);
}
