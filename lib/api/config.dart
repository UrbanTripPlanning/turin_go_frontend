class Config {
  static const String baseURL = bool.fromEnvironment('dart.vm.product')
      ? 'http://43.157.33.33:8081'
      : 'http://localhost:8081';
} 