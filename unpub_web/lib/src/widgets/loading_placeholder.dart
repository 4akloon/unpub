import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'layout.dart';

/// Reserves vertical space while page data is loading to avoid footer CLS.
Component pageLoadingPlaceholder() {
  return mainElement(
    classes: 'page-loading',
    [
      div(classes: 'page-loading-inner', []),
    ],
  );
}
