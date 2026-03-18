import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  Widget? _dashboardContent;

  int get currentIndex => _currentIndex;
  Widget? get dashboardContent => _dashboardContent;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setDashboardContent(Widget? content) {
    _dashboardContent = content;
    _currentIndex = 0; // Always switch to Dashboard tab when selecting from drawer
    notifyListeners();
  }

  void resetDashboard() {
    _dashboardContent = null;
    _currentIndex = 0;
    notifyListeners();
  }
}
