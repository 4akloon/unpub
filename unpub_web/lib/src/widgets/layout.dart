import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:universal_web/web.dart' as web;
import 'package:unpub_web/src/state/app_providers.dart';

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
            h1(classes: '_visuallyhidden', [const .text('Dart pub')]),
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

class SearchBanner extends StatelessComponent {
  const SearchBanner({super.key});

  void _submit(BuildContext context, web.Event event) {
    event.preventDefault();
    final keyword = context.read(searchKeywordProvider);
    if (keyword.isEmpty) {
      return;
    }
    final url = '/packages?q=${Uri.encodeQueryComponent(keyword)}';
    final router = Router.maybeOf(context);
    if (router != null) {
      router.push(url);
    } else {
      web.window.location.href = url;
    }
  }

  @override
  Component build(BuildContext context) {
    final keyword = context.watch(searchKeywordProvider);

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
                  events: {'submit': (event) => _submit(context, event)},
                  [
                    input(
                      type: InputType.text,
                      classes: 'input',
                      name: 'q',
                      attributes: {
                        'placeholder': 'Search Dart packages',
                        'autocomplete': 'on',
                        'autofocus': 'autofocus',
                        'value': keyword,
                      },
                      events: {
                        'input': (event) {
                          final target = event.target as web.HTMLInputElement?;
                          context.read(searchKeywordProvider.notifier).state = target?.value ?? '';
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
    return footer(
      classes: 'site-footer',
      [
        a(
          classes: 'link',
          href: 'https://github.com/bytedance/unpub',
          [const .text('Source code')],
        ),
        a(
          classes: 'link github_issue',
          href: 'https://github.com/bytedance/unpub/issues/new',
          [const .text('Report an issue')],
        ),
      ],
    );
  }
}
