class ApiConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:4000', // 10.0.2.2 is local host redirect in Android emulator
  );

  static const String datasetUrl = String.fromEnvironment(
    'DATASET_URL',
    defaultValue: 'http://10.0.2.2:4001',
  );
}
