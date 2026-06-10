import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:unpub_api/models.dart';
import 'package:unpub_web/src/services/api_service.dart';
import 'package:unpub_web/src/state/app_providers.dart';
import 'package:unpub_web/src/widgets/layout.dart';
import 'package:unpub_web/src/widgets/loading_placeholder.dart';

class HomePage extends StatefulComponent {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with PreloadStateMixin {
  ListApi? _data;

  @override
  Future<void> preloadState() async {
    _data = await apiService.fetchPackages(size: 15);
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && _data == null) {
      _load();
    }
  }

  Future<void> _load() async {
    context.read(globalLoadingProvider.notifier).state = true;
    try {
      final data = await apiService.fetchPackages(size: 15);
      setState(() => _data = data);
    } finally {
      context.read(globalLoadingProvider.notifier).state = false;
    }
  }

  String _detailUrl(ListApiPackage package) => '/packages/${Uri.encodeComponent(package.name)}';

  @override
  Component build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return pageLoadingPlaceholder();
    }

    return mainElement(
      [
        div(
          classes: 'home-lists-container',
          [
            div(
              classes: 'landing-page-title-block',
              [
                div(
                  classes: 'tooltip-base hoverable',
                  [
                    h2(classes: 'center landing-page-title tooltip-dotted', [const .text('Top Dart packages')]),
                  ],
                ),
              ],
            ),
            ul(
              classes: 'package-list',
              [
                for (final package in data.packages)
                  li(
                    classes: 'list-item',
                    [
                      h3(
                        classes: 'title',
                        [
                          Link(to: _detailUrl(package), child: .text(package.name)),
                        ],
                      ),
                      p(
                        classes: 'metadata',
                        [
                          for (final tag in package.tags) span(classes: 'package-tag', [.text(tag)]),
                        ],
                      ),
                      p(classes: 'description', [.text(package.description ?? '')]),
                    ],
                  ),
              ],
            ),
            div(
              classes: 'more',
              [
                const Link(to: '/packages', child: .text('More Dart packages...')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
