import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:unpub_web/src/pages/detail_page.dart';
import 'package:unpub_web/src/pages/home_page.dart';
import 'package:unpub_web/src/pages/list_page.dart';
import 'package:unpub_web/src/widgets/layout.dart';

@client
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return ProviderScope(
      child: Router(
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return fragment([
                const SiteHeader(),
                const SearchBanner(),
                div(classes: 'container', [child]),
                const SiteFooter(),
              ]);
            },
            routes: [
              Route(path: '/', builder: (context, state) => const HomePage()),
              Route(
                path: '/packages',
                builder: (context, state) => ListPage(state: state),
              ),
              Route(
                path: '/packages/:name',
                builder: (context, state) => DetailPage(state: state),
              ),
              Route(
                path: '/packages/:name/versions/:version',
                builder: (context, state) => DetailPage(state: state),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
