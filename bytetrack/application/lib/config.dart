class AppConfig {
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS, or your PC IP for real devices
  static const String serverIp = '192.168.1.4'; 
  static const String baseUrl = 'http://$serverIp:8000';
  static const String wsUrl = 'ws://$serverIp:8000/ws';
}
