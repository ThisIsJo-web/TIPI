import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileService {
  static final SupabaseProfileService instance = SupabaseProfileService._init();
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseProfileService._init();

  // Get current user's profile from Supabase
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint("Error fetching Supabase profile: $e");
      return null;
    }
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // Create a new user profile on Supabase
  Future<bool> createProfile({
    required String userId,
    required String name,
    required double budgetGoal,
    required String email,
  }) async {
    try {
      final now = DateTime.now();
      final activeSince = "${_months[now.month - 1]} ${now.year}";

      await _client.from('profiles').insert({
        'id': userId,
        'name': name,
        'budget_goal': budgetGoal,
        'email': email,
        'active_since': activeSince,
        'runs_completed': 0,
        'total_saved': 0.0,
        'language': 'English',
      });
      return true;
    } catch (e) {
      debugPrint("Error creating Supabase profile: $e");
      return false;
    }
  }

  // Update profile fields
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint("Error updating Supabase profile: $e");
      return false;
    }
  }
}
