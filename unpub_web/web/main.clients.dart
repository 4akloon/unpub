import 'package:jaspr/browser.dart';
import 'package:unpub_web/app.client.dart' deferred as app;

void main() {
  registerClients({
    'app': loadClient(app.loadLibrary, (p) => app.getComponentForParams(p)),
  });
}
