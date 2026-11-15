import 'tab_url_sync_stub.dart'
    if (dart.library.html) 'tab_url_sync_web.dart';

void updateTabUrl(String path, int tabIndex) {
  syncTabUrl(path, tabIndex);
}

void dispatchTabChanged() {
  notifyTabChanged();
}
