import 'package:jaspr/server.dart';

import 'package:unpub_web/app.dart';
import 'package:unpub_web/jaspr_options.dart';

/// Server entrypoint used by jaspr_builder code generation.
void main() {
  Jaspr.initializeApp(options: defaultJasprOptions);
  runApp(
    Document(
      title: 'Unpub',
      head: [
        link(
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css?family=Roboto:300,400,500,700',
        ),
        link(rel: 'stylesheet', href: '/styles.css'),
        link(rel: 'icon', type: 'image/png', href: '/favicon.png'),
      ],
      body: const App(),
    ),
  );
}
