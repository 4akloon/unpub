import 'package:jaspr_riverpod/legacy.dart';

/// Search keyword entered in the site header search bar.
final searchKeywordProvider = StateProvider<String>((ref) => '');

/// Global loading flag for client-side data fetches.
final globalLoadingProvider = StateProvider<bool>((ref) => false);
