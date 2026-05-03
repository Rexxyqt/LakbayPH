import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:application/screens/welcome_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../config.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isOnTrip = false;
  int _seatedCount = 0;
  int _standingCount = 0;
  int _capacity = 32;
  String _busNumber = 'N/A';
  String _plateNumber = 'N/A';
  late WebSocketChannel _channel;
  StreamSubscription<Position>? _positionStream;
  bool _isNorthbound = true;

  @override
  void initState() {
    super.initState();
    _fetchState();
    _connectWebSocket();
  }

  Future<void> _fetchState() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/get_state'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isOnTrip = data['is_on_trip'] ?? false;
          _busNumber = data['bus_number'] ?? 'N/A';
          _plateNumber = data['plate_number'] ?? 'N/A';
          _capacity = data['capacity'] ?? 32;
        });
      }
    } catch (e) {
      debugPrint('Error fetching state: $e');
    }
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse(AppConfig.wsUrl),
    );
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      setState(() {
        _seatedCount = data['seated'] ?? 0;
        _standingCount = data['standing'] ?? 0;
        // Also update bus info if it changed
        if (data['bus_number'] != null) _busNumber = data['bus_number'];
        if (data['plate_number'] != null) _plateNumber = data['plate_number'];
      });
    });
  }

  Future<void> _toggleTrip() async {
    final endpoint = _isOnTrip ? 'end_trip' : 'start_trip';
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/$endpoint'));
      
      if (!_isOnTrip) {
        await _startLocationUpdates();
      } else {
        await _stopLocationUpdates();
      }

      setState(() => _isOnTrip = !_isOnTrip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection Error')),
        );
      }
    }
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _sendLocationToServer(position);
    });
  }

  Future<void> _stopLocationUpdates() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _manualPin() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      await _sendLocationToServer(position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin Updated Manually'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Manual pin error: $e');
    }
  }

  Future<void> _sendLocationToServer(Position position) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'isNorthbound': _isNorthbound,
        }),
      );
    } catch (e) {
      debugPrint('Error sending location: $e');
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int total = _seatedCount + _standingCount;
    double progress = (total / (_capacity > 0 ? _capacity : 1)).clamp(0.0, 1.0);

    return PopScope(
      canPop: !_isOnTrip,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isOnTrip) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please end your trip before leaving the dashboard.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFD700),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              if (_isOnTrip) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('End your trip first!')),
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
          title: Text(
            'DRIVER CONSOLE',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.account_circle, color: Colors.black),
            )
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text('UNIT: $_busNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus, size: 40),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_plateNumber, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                      const Text('Edsa Carousel • Monumento - PITX', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _toggleTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnTrip ? Colors.black : const Color(0xFFFFD700),
                  foregroundColor: _isOnTrip ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
                child: Text(_isOnTrip ? 'END TRIP' : 'START TRIP', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_isOnTrip) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('DIRECTION:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(_isNorthbound ? 'NORTHBOUND' : 'SOUTHBOUND', 
                              style: TextStyle(color: _isNorthbound ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                            Switch(
                              value: _isNorthbound,
                              onChanged: (val) {
                                setState(() => _isNorthbound = val);
                                if (_isOnTrip) _manualPin(); // Update immediately
                              },
                              activeThumbColor: Colors.blue,
                              inactiveTrackColor: Colors.red.withOpacity(0.5),
                              inactiveThumbColor: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _manualPin,
                        icon: const Icon(Icons.location_on),
                        label: const Text('UPDATE PIN MANUALLY'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.visibility_outlined, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('COMPUTER VISION ACTIVE\nAI system counting passengers in real-time', 
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.show_chart),
                        SizedBox(width: 10),
                        Text('LIVE PASSENGER COUNT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('$total', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                    const Text('Total Passengers', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Seated', _seatedCount, _capacity)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('Standing', _standingCount, _capacity)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      color: Colors.green,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 10),
                    Text('${(progress * 100).toInt()}% of seated capacity', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.gps_fixed),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('GPS TRACKING ACTIVE\nYour bus is visible to all commuters', 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatCard(String label, int count, int cap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('/ $cap seats', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
