class ApiConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue:
        'https://tipi-wyug.onrender.com', // 10.0.2.2 is local host redirect in Android emulator
  );

  static const String datasetUrl = String.fromEnvironment(
    'DATASET_URL',
    defaultValue: 'https://tipi-1.onrender.com',
  );
}
