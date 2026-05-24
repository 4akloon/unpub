import 'package:jaspr/jaspr.dart';

/// Shared application state for loading indicator and search keyword.
class AppState {
  AppState._();

  static final AppState instance = AppState._();

  bool loading = false;
  String keyword = '';

  final List<void Function()> _listeners = <void Function()>[];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    if (!kIsWeb) {
      return;
    }
    for (final listener in _listeners) {
      listener();
    }
  }

  void setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void setKeyword(String value) {
    keyword = value;
    notifyListeners();
  }
}
