class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kxlnxaymkbrpxgtzfuwy.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_nbX3K9mTngOunJEUwuQHaQ_lyT7Kgan',
  );
}
