import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:universal_web/web.dart' as web;
import 'package:unpub_web/src/app_state.dart';

Component mainElement(List<Component> children, {String? classes}) {
  return Component.element(
    tag: 'main',
    classes: classes,
    children: children,
  );
}

class SiteHeader extends StatelessComponent {
  const SiteHeader({super.key});

  @override
  Component build(BuildContext context) {
    return header(
      classes: 'site-header-row',
      [
        div(
          classes: 'container site-header',
          [
            h1(classes: '_visuallyhidden', [.text('Dart pub')]),
            button(classes: 'hamburger', []),
            div(classes: 'mask', []),
            div(
              classes: 'nav-wrap',
              [
                div(
                  classes: 'nav-header',
                  [
                    Link(
                      to: '/',
                      classes: 'logo',
                      child: img(
                        src: '/logo.svg',
                        alt: 'dart pub logo',
                      ),
                    ),
                    div(classes: '_flex-space', []),
                    button(classes: 'close', []),
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

class SearchBanner extends StatefulComponent {
  const SearchBanner({super.key});

  @override
  State<SearchBanner> createState() => _SearchBannerState();
}

class _SearchBannerState extends State<SearchBanner> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      AppState.instance.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  void _submit(web.Event event) {
    event.preventDefault();
    if (AppState.instance.keyword.isEmpty) {
      return;
    }
    final url = '/packages?q=${Uri.encodeQueryComponent(AppState.instance.keyword)}';
    final router = Router.maybeOf(context);
    if (router != null) {
      router.push(url);
    } else {
      web.window.location.href = url;
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: '_banner-bg',
      [
        div(
          classes: 'container',
          [
            div(
              classes: 'home-banner',
              [
                form(
                  classes: 'search-bar',
                  action: '/packages',
                  events: {'submit': _submit},
                  [
                    input(
                      type: InputType.text,
                      classes: 'input',
                      name: 'q',
                      attributes: {
                        'placeholder': 'Search Dart packages',
                        'autocomplete': 'on',
                        'autofocus': 'autofocus',
                        'value': AppState.instance.keyword,
                      },
                      events: {
                        'input': (event) {
                          final target = event.target as web.HTMLInputElement?;
                          AppState.instance.setKeyword(target?.value ?? '');
                        },
                      },
                    ),
                    button(classes: 'icon', attributes: {'type': 'submit'}, []),
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

class SiteFooter extends StatelessComponent {
  const SiteFooter({super.key});

  @override
  Component build(BuildContext context) {
    if (AppState.instance.loading) {
      return fragment([]);
    }

    return footer(
      classes: 'site-footer',
      [
        a(
          classes: 'link',
          href: 'https://github.com/bytedance/unpub',
          [.text('Source code')],
        ),
        a(
          classes: 'link github_issue',
          href: 'https://github.com/bytedance/unpub/issues/new',
          [.text('Report an issue')],
        ),
      ],
    );
  }
}
