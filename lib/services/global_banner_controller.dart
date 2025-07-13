import 'package:flutter/material.dart';

class GlobalBannerController extends ChangeNotifier {
  Widget? _banner;
  bool get isVisible => _banner != null;
  Widget? get banner => _banner;

  void showBanner(Widget banner) {
    _banner = banner;
    notifyListeners();
  }

  void hideBanner() {
    _banner = null;
    notifyListeners();
  }
} 