class ApiConfig {
  static const String baseUrl = 'http://localhost:5217/api';
  
  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';
  static const String switchOrganization = '$baseUrl/auth/switch-organization';
  

}
