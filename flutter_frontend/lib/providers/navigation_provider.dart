import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NAVIGATION STATE
/// Simple data class to hold our current tab and dashboard content.
class NavigationState {
  final int currentIndex;
  final String activeModule;
  final Widget? dashboardContent;
  final Widget? manageUsersContent;
  final Widget? hrManagementContent;

  NavigationState({
    this.currentIndex = 0,
    this.activeModule = 'dashboard',
    this.dashboardContent,
    this.manageUsersContent,
    this.hrManagementContent,
  });

  NavigationState copyWith({
    int? currentIndex,
    String? activeModule,
    Widget? dashboardContent,
    Widget? manageUsersContent,
    Widget? hrManagementContent,
    bool? clearDashboard,
    bool? clearManageUsers,
    bool? clearHRManagement,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      activeModule: activeModule ?? this.activeModule,
      dashboardContent: (clearDashboard == true) ? null : (dashboardContent ?? this.dashboardContent),
      manageUsersContent: (clearManageUsers == true) ? null : (manageUsersContent ?? this.manageUsersContent),
      hrManagementContent: (clearHRManagement == true) ? null : (hrManagementContent ?? this.hrManagementContent),
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
    String module = 'dashboard';
    if (index == 1) module = 'hrm';
    if (index == 2) module = 'user_mgmt';
    if (index == 3) module = 'tasks';
    
    state = state.copyWith(
      currentIndex: index,
      activeModule: module,
    );
  }

  /// Switches the Dashboard's content (e.g., from Drawer selections).
  void setDashboardContent(Widget? content, {String? module}) {
    state = state.copyWith(
      dashboardContent: content,
      clearDashboard: content == null,
      currentIndex: 0, // Always switch back to the Dashboard tab
      activeModule: module ?? 'dashboard',
    );
  }

  /// Switches the User Management's content.
  void setManageUsersContent(Widget? content, {String? module}) {
    state = state.copyWith(
      manageUsersContent: content,
      clearManageUsers: content == null,
      currentIndex: 2, // Switch to User Management tab (index 2 for Admin)
      activeModule: module ?? 'user_mgmt',
    );
  }

  /// Switches the HR Management's content.
  void setHRManagementContent(Widget? content, {String? module}) {
    state = state.copyWith(
      hrManagementContent: content,
      clearHRManagement: content == null,
      currentIndex: 1, // Switch to HR Management tab (index 1 for Admin)
      activeModule: module ?? 'hrm',
    );
  }

  /// Resets everything and returns to index 0.
  void resetNavigation() {
    state = NavigationState();
  }
}
