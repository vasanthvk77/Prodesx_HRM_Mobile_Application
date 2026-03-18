import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NAVIGATION STATE
/// Simple data class to hold our current tab and dashboard content.
class NavigationState {
  final int currentIndex;
  final Widget? dashboardContent;
  final Widget? manageUsersContent;

  NavigationState({
    this.currentIndex = 0,
    this.dashboardContent,
    this.manageUsersContent,
  });

  NavigationState copyWith({
    int? currentIndex,
    Widget? dashboardContent,
    Widget? manageUsersContent,
    bool? clearDashboard,
    bool? clearManageUsers,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      dashboardContent: (clearDashboard == true) ? null : (dashboardContent ?? this.dashboardContent),
      manageUsersContent: (clearManageUsers == true) ? null : (manageUsersContent ?? this.manageUsersContent),
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
      clearDashboard: content == null,
      currentIndex: 0, // Always switch back to the Dashboard tab
    );
  }

  /// Switches the User Management's content.
  void setManageUsersContent(Widget? content) {
    state = state.copyWith(
      manageUsersContent: content,
      clearManageUsers: content == null,
      currentIndex: 2, // Switch to User Management tab (index 2 for Admin)
    );
  }

  /// Resets everything and returns to index 0.
  void resetNavigation() {
    state = NavigationState();
  }
}
