import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// 1. DEFINE THE STATE OBJECT
/// This simple class holds all the data our UI needs for authentication.
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
  });

  // Getter for easy check in UI
  bool get isAuthenticated => token != null;

  /// Helper method to create a copy of the state with some changes
  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearUser ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 2. DEFINE THE PROVIDER
/// This global constant allows any widget to access our authentication logic.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// 3. DEFINE THE NOTIFIER (LOGIC)
/// This class handles all the "How it works" part of authentication.
class AuthNotifier extends StateNotifier<AuthState> {
  // We initialize with an empty state
  AuthNotifier() : super(AuthState()) {
    _loadStoredData();
  }

  final _storage = const FlutterSecureStorage();
  final _repo = AuthRepository();

  /// Loads the saved login session from storage when the app starts.
  Future<void> _loadStoredData() async {
    final token = await _storage.read(key: 'auth_token');
    final userJson = await _storage.read(key: 'user_data');

    if (token != null && userJson != null) {
      state = state.copyWith(
        token: token,
        user: User.fromJson(jsonDecode(userJson)),
      );
    }
  }

  /// Handles the login process by calling the Repository.
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final data = await _repo.login(email, password);
      
      final token = data['token'];
      final user = data['user'] as User;

      // 1. Save data to secure storage
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));

      // 2. Update the state for the UI
      state = state.copyWith(
        token: token,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Handles logout by clearing memory and secure storage.
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    state = AuthState(); // Reset state to empty
  }

  /// Handles switching organizations and updating the session.
  Future<void> switchOrganization(String organizationId) async {
    if (state.token == null) return;
    
    state = state.copyWith(isLoading: true);

    try {
      final data = await _repo.switchOrganization(state.token!, organizationId);
      final newToken = data['token'];
      final newUser = data['user'] as User?;

      // Update storage
      await _storage.write(key: 'auth_token', value: newToken);
      
      User? updatedUser = newUser;
      
      // If backend didn't return full user info, update our local copy
      if (updatedUser == null && state.user != null) {
        updatedUser = User(
          id: state.user!.id,
          name: state.user!.name,
          email: state.user!.email,
          role: state.user!.role,
          organizationId: int.tryParse(organizationId),
          organizationLogo: state.user!.organizationLogo,
        );
      }

      if (updatedUser != null) {
        await _storage.write(key: 'user_data', value: jsonEncode(updatedUser.toJson()));
      }

      state = state.copyWith(
        token: newToken,
        user: updatedUser,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}
