import 'dart:math';

import 'package:intl/intl.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:unpub_api/models.dart';

import 'package:unpub_web/src/app_state.dart';
import 'package:unpub_web/src/services/api_service.dart';
import 'package:unpub_web/src/widgets/layout.dart';

class ListPage extends StatefulComponent {
  const ListPage({required this.state, super.key});

  final RouteState state;

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> with PreloadStateMixin {
  static const int pageSize = 10;

  ListApi? _data;
  String? _query;
  int _currentPage = 0;

  @override
  Future<void> preloadState() async {
    _query = component.state.queryParams['q'];
    _currentPage = int.tryParse(component.state.queryParams['page'] ?? '0') ?? 0;
    _data = await apiService.fetchPackages(
      size: pageSize,
      page: _currentPage,
      q: _query,
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      return;
    }
    _query = component.state.queryParams['q'];
    _currentPage = int.tryParse(component.state.queryParams['page'] ?? '0') ?? 0;
    if (_data == null) {
      _load();
    }
  }

  @override
  void didUpdateComponent(ListPage oldComponent) {
    super.didUpdateComponent(oldComponent);
    final nextQuery = component.state.queryParams['q'];
    final nextPage = int.tryParse(component.state.queryParams['page'] ?? '0') ?? 0;
    if (nextQuery != _query || nextPage != _currentPage) {
      _query = nextQuery;
      _currentPage = nextPage;
      _load();
    }
  }

  Future<void> _load() async {
    AppState.instance.setLoading(true);
    try {
      final data = await apiService.fetchPackages(
        size: pageSize,
        page: _currentPage,
        q: _query,
      );
      setState(() => _data = data);
    } finally {
      AppState.instance.setLoading(false);
    }
  }

  int get _pageCount {
    final data = _data;
    if (data == null) {
      return 0;
    }
    return (data.count / pageSize).ceil();
  }

  List<int> get _pages {
    final data = _data;
    if (data == null) {
      return [];
    }
    final leftCount = min(_currentPage, 5);
    final rightCount = min(_pageCount - _currentPage, 5);
    final offset = max(_currentPage - 5, 0);
    return List<int>.generate(leftCount + rightCount + 1, (index) => index + offset);
  }

  String _detailUrl(ListApiPackage package) => '/packages/${Uri.encodeComponent(package.name)}';

  String _listUrl(int page) {
    final queryParameters = <String, String>{};
    if (_query != null) {
      queryParameters['q'] = _query!;
    }
    if (page > 0) {
      queryParameters['page'] = page.toString();
    }
    if (queryParameters.isEmpty) {
      return '/packages';
    }
    return Uri(path: '/packages', queryParameters: queryParameters).toString();
  }

  @override
  Component build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return fragment([]);
    }

    final dateFormat = DateFormat.yMMMd();

    return mainElement(
      [
        p(
          classes: 'package-count',
          [
            span([.text('${data.count}')]),
            .text(' results'),
          ],
        ),
        ul(
          classes: 'package-list',
          [
            for (final package in data.packages)
              li(
                classes: 'list-item -full',
                [
                  h3(
                    classes: 'title',
                    [
                      Link(to: _detailUrl(package), child: .text(package.name)),
                    ],
                  ),
                  p(classes: 'description', [.text(package.description ?? '')]),
                  p(
                    classes: 'metadata',
                    [
                      .text('v '),
                      Link(to: _detailUrl(package), child: .text(package.latest)),
                      .text(' • Updated: '),
                      span([.text(dateFormat.format(package.updatedAt))]),
                      for (final tag in package.tags)
                        span(classes: 'package-tag', [.text(tag)]),
                    ],
                  ),
                ],
              ),
          ],
        ),
        ul(
          classes: 'pagination',
          [
            li(
              classes: _currentPage == 0 ? '-disabled' : null,
              [
                Link(to: _listUrl(_currentPage - 1), child: span([.text('«')])),
              ],
            ),
            for (final page in _pages)
              li(
                classes: _currentPage == page ? '-disabled' : null,
                [
                  Link(to: _listUrl(page), child: span([.text('${page + 1}')])),
                ],
              ),
            li(
              classes: _currentPage == _pageCount - 1 ? '-disabled' : null,
              [
                Link(to: _listUrl(_currentPage + 1), child: span([.text('»')])),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
