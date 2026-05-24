import 'package:intl/intl.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:unpub_api/models.dart';

import 'package:unpub_web/src/app_state.dart';
import 'package:unpub_web/src/services/api_service.dart';
import 'package:unpub_web/src/widgets/layout.dart';
import 'package:unpub_web/src/widgets/loading_placeholder.dart';

class DetailPage extends StatefulComponent {
  const DetailPage({required this.state, super.key});

  final RouteState state;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with PreloadStateMixin {
  WebapiDetailView? _package;
  String? _packageName;
  String? _packageVersion;
  int _activeTab = 0;
  bool _packageNotExists = false;

  @override
  Future<void> preloadState() async {
    await _fetchPackage();
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && _package == null && !_packageNotExists) {
      _load();
    }
  }

  @override
  void didUpdateComponent(DetailPage oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.state.location != component.state.location) {
      _load();
    }
  }

  Future<void> _fetchPackage() async {
    final name = component.state.params['name'];
    final version = component.state.params['version'];

    if (name == null) {
      return;
    }

    _packageName = name;
    _packageVersion = version;
    _activeTab = 0;
    _packageNotExists = false;
    _package = null;

    try {
      _package = await apiService.fetchPackage(name, version);
    } on PackageNotExistsException {
      _packageNotExists = true;
    }
  }

  Future<void> _load() async {
    AppState.instance.setLoading(true);
    try {
      await _fetchPackage();
      setState(() {});
    } finally {
      AppState.instance.setLoading(false);
    }
  }

  String? _markdownToHtml(String? markdown) {
    if (markdown == null) {
      return null;
    }
    return md.markdownToHtml(markdown);
  }

  String get _pubDevLink {
    final packageName = _packageName;
    if (packageName == null) {
      return 'https://pub.dev/packages/';
    }
    var url = 'https://pub.dev/packages/$packageName';
    if (_packageVersion != null) {
      url += '/versions/$_packageVersion';
    }
    return url;
  }

  String _listUrl(String query) {
    return Uri(path: '/packages', queryParameters: {'q': query}).toString();
  }

  String _detailUrl(String name, [String? version]) {
    if (version == null) {
      return '/packages/${Uri.encodeComponent(name)}';
    }
    return '/packages/${Uri.encodeComponent(name)}/versions/${Uri.encodeComponent(version)}';
  }

  Component _tabButton(String label, int index) {
    return li(
      classes: _activeTab == index ? 'tab-button -active' : 'tab-button',
      attributes: {'role': 'button'},
      events: {
        'click': (_) => setState(() => _activeTab = index),
      },
      [.text(label)],
    );
  }

  @override
  Component build(BuildContext context) {
    if (_packageNotExists) {
      return mainElement(
        [
          div(
            classes: 'not-exists',
            [
              div([const .text('This is not a private package, click link below to view it:')]),
              a(
                href: _pubDevLink,
                attributes: {'target': '_blank', 'rel': 'nofollow'},
                [.text(_pubDevLink)],
              ),
            ],
          ),
        ],
      );
    }

    final package = _package;
    if (package == null) {
      return pageLoadingPlaceholder();
    }

    final dateFormat = DateFormat.yMMMd();
    final readmeHtml = _markdownToHtml(package.readme);
    final changelogHtml = _markdownToHtml(package.changelog);

    return mainElement(
      [
        div(
          classes: 'detail-header',
          [
            h2(classes: 'title', [.text('${package.name} ${package.version}')]),
            div(
              classes: 'metadata',
              [
                const .text('Published '),
                span([.text(dateFormat.format(package.createdAt))]),
                div(
                  classes: 'tags',
                  [
                    for (final tag in package.tags)
                      span(classes: 'package-tag', [.text(tag)]),
                  ],
                ),
              ],
            ),
          ],
        ),
        div(
          classes: 'detail-container',
          [
            ul(
              classes: 'detail-tabs-header',
              [
                _tabButton('README.md', 0),
                _tabButton('CHANGELOG.md', 1),
                _tabButton('Versions', 2),
              ],
            ),
            div(
              classes: 'detail-tabs-content main',
              [
                section(
                  classes: _activeTab == 0 ? 'tab-content markdown-body -active' : 'tab-content markdown-body',
                  id: 'readme',
                  [if (readmeHtml != null) raw(readmeHtml)],
                ),
                section(
                  classes: _activeTab == 1 ? 'tab-content markdown-body -active' : 'tab-content markdown-body',
                  id: 'changelog',
                  [if (changelogHtml != null) raw(changelogHtml)],
                ),
                section(
                  classes: _activeTab == 2 ? 'tab-content -active' : 'tab-content',
                  [
                    table(
                      classes: 'version-table',
                      [
                        thead(
                          [
                            tr(
                              [
                                th([const .text('Version')]),
                                th([const .text('Uploaded')]),
                                th(classes: 'documentation', attributes: {'width': '60'}, [const .text('Documentation')]),
                                th(classes: 'archive', attributes: {'width': '60'}, [const .text('Archive')]),
                              ],
                            ),
                          ],
                        ),
                        tbody(
                          [
                            for (final item in package.versions)
                              tr(
                                [
                                  td(
                                    [
                                      strong(
                                        [
                                          Link(
                                            to: _detailUrl(package.name, item.version),
                                            child: .text(item.version),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  td([.text(dateFormat.format(item.createdAt))]),
                                  td(
                                    classes: 'documentation',
                                    [
                                      a(
                                        href: '/documentation/${package.name}/${item.version}/',
                                        attributes: {'rel': 'nofollow'},
                                        [
                                          img(
                                            src:
                                                'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNHB4IiBoZWlnaHQ9IjI0cHgiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iIzAwMDAwMCI+JTBBICAgIDxwYXRoIGQ9Ik0wIDBoMjR2MjRIMHoiIGZpbGw9Im5vbmUiLz4lMEEgICAgPHBhdGggZD0iTTE5IDNINWMtMS4xIDAtMiAuOS0yIDJ2MTRjMCAxLjEuOSAyIDIgMmgxNGMxLjEgMCAyLS45IDItMlY1YzAtMS4xLS45LTItMi0yem0tMS45OSA2SDdWN2gxMC4wMXYyem0wIDRIN3YtMmgxMC4wMXYyem0tMyA0SDd2LTJoNy4wMXYyeiIvPiUwQTwvc3ZnPg==',
                                            alt: 'Documentation for ${package.name} ${item.version}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  td(
                                    classes: 'archive',
                                    [
                                      a(
                                        href: '/packages/${package.name}/versions/${item.version}.tar.gz',
                                        [
                                          img(
                                            src:
                                                'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNHB4IiBoZWlnaHQ9IjI0cHgiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iIzAwMDAwMCI+JTBBICAgIDxwYXRoIGQ9Ik0xOSA5aC00VjNIOXY2SDVsNyA3IDctN3pNNSAxOHYyaDE0di0ySDV6Ii8+JTBBICAgIDxwYXRoIGQ9Ik0wIDBoMjR2MjRIMHoiIGZpbGw9Im5vbmUiLz4lMEE8L3N2Zz4=',
                                            alt: 'Download ${package.name} ${item.version}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            aside(
              classes: 'detail-info-box',
              [
                h3(classes: 'title', [const .text('About')]),
                p([.text(package.description)]),
                p(
                  [
                    if (package.homepage.isNotEmpty)
                      a(classes: 'link', href: package.homepage, [const .text('Homepage')]),
                    if (package.homepage.isNotEmpty) br(),
                    a(
                      classes: 'link',
                      href: '/documentation/${package.name}/${package.version}/',
                      [const .text('API reference')],
                    ),
                    br(),
                  ],
                ),
                h3(classes: 'title', [const .text('Author')]),
                div(
                  [
                    for (final email in package.authors)
                      if (email != null)
                        div(
                          classes: 'author',
                          [
                            a(href: 'mailto:$email', [.text(email)]),
                            Link(
                              to: _listUrl('email:$email'),
                              attributes: const {'rel': 'nofollow'},
                              child: const .text(' search'),
                            ),
                          ],
                        ),
                  ],
                ),
                h3(classes: 'title', [const .text('Uploader')]),
                div(
                  [
                    for (final email in package.uploaders)
                      div(
                        classes: 'author',
                        [
                          a(href: 'mailto:$email', [.text(email)]),
                          Link(
                            to: _listUrl('email:$email'),
                            attributes: const {'rel': 'nofollow'},
                            child: const .text(' search'),
                          ),
                        ],
                      ),
                  ],
                ),
                h3(classes: 'title', [const .text('Dependencies')]),
                p(
                  [
                    for (final dependency in package.dependencies ?? <String>[])
                      Link(
                        to: _detailUrl(dependency),
                        child: .text('$dependency${dependency == package.dependencies!.last ? '' : ', '}'),
                      ),
                  ],
                ),
                h3(classes: 'title', [const .text('More')]),
                p(
                  [
                    Link(
                      to: _listUrl('dependency:${package.name}'),
                      attributes: const {'rel': 'nofollow'},
                      child: .text('Packages that depend on ${package.name}'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
