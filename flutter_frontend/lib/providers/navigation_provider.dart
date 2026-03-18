import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NAVIGATION STATE
/// Simple data class to hold our current tab and dashboard content.
class NavigationState {
  final int currentIndex;
  final Widget? dashboardContent;

  NavigationState({
    this.currentIndex = 0,
    this.dashboardContent,
  });

  NavigationState copyWith({
    int? currentIndex,
    Widget? dashboardContent,
    bool clearContent = false,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      dashboardContent: clearContent ? null : (dashboardContent ?? this.dashboardContent),
    );
  }
}

/// NAVIGATION PROVIDER
/// Manages the bottom bar and dynamic dashboard content.
final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(NavigationState());

  /// Sets the active tab on the bottom bar.
  void setIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  /// Switches the Dashboard's content (e.g., from Drawer selections).
  void setDashboardContent(Widget? content) {
    state = state.copyWith(
      dashboardContent: content,
      currentIndex: 0, // Always switch back to the Dashboard tab
    );
  }

  /// Resets the Dashboard and returns to index 0.
  void resetDashboard() {
    state = NavigationState();
  }
}
