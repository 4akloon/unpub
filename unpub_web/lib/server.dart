import 'package:jaspr/server.dart';
import 'package:shelf/shelf.dart';
import 'package:unpub_web/app.dart';
import 'package:unpub_web/jaspr_options.dart';
import 'package:unpub_web/src/services/api_service.dart';
import 'package:unpub_web/static_assets.dart';
import 'package:unpub_web/src/services/api_service.dart';

Handler buildHandler({String apiBaseUrl = 'http://127.0.0.1:4000'}) {
  apiService.configure(baseUrl: apiBaseUrl);
  _ensureInitialized();
  return serveApp((request, render) {
    return render(
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
  });
}

bool _initialized = false;

void _ensureInitialized() {
  if (_initialized) {
    return;
  }
  Jaspr.initializeApp(options: defaultJasprOptions);
  _initialized = true;
}
