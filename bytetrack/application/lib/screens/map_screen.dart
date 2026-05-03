import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/services.dart';
import '../models/bus.dart';
import '../config.dart';
import 'bus_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const List<ml.LatLng> edsaPoints = [
    ml.LatLng(14.6575128, 120.9840488), // Monumento
    ml.LatLng(14.6594371, 120.9901416), // Bagong Barrio
    ml.LatLng(14.6596102, 121.0006766), // Balintawak
    ml.LatLng(14.6585, 121.0118), // Kaingin
    ml.LatLng(14.6576553, 121.0196921), // Roosevelt
    ml.LatLng(14.6521583, 121.0322588), // North Ave
    ml.LatLng(14.6423458, 121.0381488), // Quezon Ave
    ml.LatLng(14.6300, 121.0440), // Nepa Q-Mart
    ml.LatLng(14.6152145, 121.0523456), // Main Ave
    ml.LatLng(14.6074212, 121.0560824), // Santolan
    ml.LatLng(14.5878456, 121.0566898), // Ortigas
    ml.LatLng(14.5672154, 121.0450588), // Guadalupe
    ml.LatLng(14.5542, 121.0345), // Buendia
    ml.LatLng(14.5491542, 121.0283498), // Ayala
    ml.LatLng(14.5376543, 121.0012345), // Taft
    ml.LatLng(14.5340, 120.9900), // Roxas
    ml.LatLng(14.5360, 120.9810), // MOA
    ml.LatLng(14.5340, 120.9900), // Return to Roxas junction
    ml.LatLng(14.5290, 121.0000), // Tramo
    ml.LatLng(14.5240, 120.9920), // DFA
    ml.LatLng(14.5190, 120.9890), // Ayala Malls
    ml.LatLng(14.5111647, 120.9917209), // PITX
  ];

  static const List<String> edsaPointNames = [
    'Monumento', 'Bagong Barrio', 'Balintawak', 'Kaingin', 'Roosevelt', 
    'North Avenue', 'Quezon Avenue', 'Nepa Q-Mart', 'Main Avenue', 'Santolan', 
    'Ortigas', 'Guadalupe', 'Buendia', 'Ayala', 'Taft', 'Roxas', 'MOA', 
    'Roxas Junction', 'Tramo', 'DFA/Shell/Starbucks', 'Ayala Malls Manila Bay', 'PITX'
  ];

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  ml.MapLibreMapController? _mapController;
  final Map<String, Bus> _activeBuses = {};
  WebSocketChannel? _channel;
  bool _isMapView = true;
  bool _is3D = false;
  bool _isDarkMap = true;

  final String _darkStyleUrl = "https://tiles.openfreemap.org/styles/dark";
  final String _lightStyleUrl = "https://tiles.openfreemap.org/styles/liberty";

  String get _styleUrl => _isDarkMap ? _darkStyleUrl : _lightStyleUrl;
  Color get _overlayTextColor => _isDarkMap ? Colors.white : Colors.black;

  final Map<String, int> _busRouteIndices = {};
  final Map<String, double> _busRouteProgress = {};
  final Set<String> _registeredBusLabels = {};
  final Map<String, Uint8List> _cachedBusLabels = {};
  bool _isMapReady = false;
  Timer? _simTimer;
  bool _hasCenteredOnBus = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            if (data['latitude'] != null && data['longitude'] != null) {
              final newBus = Bus.fromJson(data);
              bool needsRebuild = false;

              if (_activeBuses.containsKey(newBus.id)) {
                final existing = _activeBuses[newBus.id]!;
                
                // Always update passenger counts
                existing.passengerCount = newBus.passengerCount;
                existing.standingCount = newBus.standingCount;
                
                // If this is a REAL bus (not in our simulated dummy routes), update its GPS and ETA data
                if (!_busRouteIndices.containsKey(existing.id)) {
                  existing.location = newBus.location;
                  if (data['currentStop'] != null) existing.currentStop = newBus.currentStop;
                  if (data['nextStop'] != null) existing.nextStop = newBus.nextStop;
                  if (data['eta'] != null) existing.eta = newBus.eta;
                }
                
                // Rebuild list view if needed
                if (!_isMapView) needsRebuild = true;
              } else {
                _activeBuses[newBus.id] = newBus;
                needsRebuild = true;
              }
              
              if (_simTimer == null) {
                _startSimulation();
              }

              // Apply the rebuild if needed
              if (needsRebuild && mounted) {
                setState(() {});
              }
              // Removed _updateMarkers() to avoid conflict with simulation loop
            }
          } catch (e) {
            debugPrint("WebSocket decoding error: $e");
          }
        },
        onDone: () => Future.delayed(const Duration(seconds: 3), _connectWebSocket),
        onError: (e) => Future.delayed(const Duration(seconds: 3), _connectWebSocket),
      );
    } catch (e) {
      Future.delayed(const Duration(seconds: 3), _connectWebSocket);
    }
  }

  void _startSimulation() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        bool needsUpdate = false;
        for (var busId in _activeBuses.keys.toList()) {
          if (!_busRouteIndices.containsKey(busId)) {
            // If a new bus arrives from WebSocket, put it on the yellow line at Station 0
            _busRouteIndices[busId] = 0;
            _busRouteProgress[busId] = 0.0;
          }
          
          int currentIndex = _busRouteIndices[busId]!;
          double progress = _busRouteProgress[busId] ?? 0.0;
          
          progress += 0.015; // 1.5% per 200ms (smooth, realistic speed, no lag)
          if (progress >= 1.0) {
            progress = 0.0;
            currentIndex = (currentIndex + 1) % MapScreen.edsaPoints.length;
            _busRouteIndices[busId] = currentIndex;
          }
          _busRouteProgress[busId] = progress;
          
          final currentPoint = MapScreen.edsaPoints[currentIndex];
          final nextIndex = (currentIndex + 1) % MapScreen.edsaPoints.length;
          final nextPoint = MapScreen.edsaPoints[nextIndex];
          
          // Linear interpolation
          final lat = currentPoint.latitude + (nextPoint.latitude - currentPoint.latitude) * progress;
          final lng = currentPoint.longitude + (nextPoint.longitude - currentPoint.longitude) * progress;
          
          final currentStop = MapScreen.edsaPointNames[currentIndex];
          final nextStop = MapScreen.edsaPointNames[nextIndex];
          int timeRemainingSeconds = ((1.0 - progress) / 0.015 * 0.2).round();
          String etaStr = timeRemainingSeconds > 0 ? "$timeRemainingSeconds sec" : "Now";

          final bus = _activeBuses[busId]!;
          bus.location = ll.LatLng(lat, lng);
          bus.currentStop = currentStop;
          bus.nextStop = nextStop;
          bus.eta = etaStr;
          
        }
        
        _updateMarkers(); // Fire and forget (syncs both dummy and real buses)
        
        if (needsUpdate && !_isMapView && mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint("Simulation Loop Error: $e");
      }
    });
  }

  void _onMapTapped(Point<double> point, ml.LatLng coords) {
    debugPrint("Map background tapped at: ${coords.latitude}, ${coords.longitude}");
  }

  void _onCameraIdle() {
    // Intentionally left blank.
  }

  Future<void> _updateMarkers() async {
    if (_mapController == null || !_isMapReady) return;
    
    final List<Map<String, dynamic>> features = [];

    for (var bus in _activeBuses.values) {
      final ml.LatLng pos = ml.LatLng(bus.location.latitude, bus.location.longitude);
      
      if (!_hasCenteredOnBus) {
        _mapController?.animateCamera(ml.CameraUpdate.newLatLngZoom(pos, 14));
        _hasCenteredOnBus = true;
      }

      if (!_registeredBusLabels.contains(bus.id)) {
        _registeredBusLabels.add(bus.id);
        _generateAndAddBusLabel(bus.id);
      }

      features.add({
        "type": "Feature",
        "id": bus.id,
        "geometry": {
          "type": "Point",
          "coordinates": [pos.longitude, pos.latitude]
        },
        "properties": {
          "busId": bus.id,
          "labelImage": "bus_label_${bus.id}"
        }
      });
    }

    final geojson = {
      "type": "FeatureCollection",
      "features": features
    };

    try {
      await _mapController!.setGeoJsonSource("buses_source", geojson);
    } catch (e) {
      debugPrint("Error updating GeoJSON source: $e");
    }
  }

  Future<void> _generateAndAddBusLabel(String busId) async {
    try {
      if (!_cachedBusLabels.containsKey(busId)) {
        final bytes = await _createBusLabelBitmap(busId);
        _cachedBusLabels[busId] = bytes;
      }
      await _mapController?.addImage("bus_label_$busId", _cachedBusLabels[busId]!);
    } catch (e) {
      debugPrint("Error generating bus label: $e");
    }
  }

  Future<Uint8List> _createBusLabelBitmap(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final width = textPainter.width + 40;
    final height = textPainter.height + 24;
    
    final rrect = RRect.fromLTRBR(0, 0, width, height, const Radius.circular(16));
    
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect.shift(const Offset(2, 4)), shadowPaint);
    
    // Yellow Pill
    final paint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(rrect, paint);
    
    // Black Border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);
    
    textPainter.paint(canvas, const Offset(20, 12));
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt() + 10, height.toInt() + 10);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _mapController = controller;
    _mapController!.onFeatureTapped.add((point, coords, id, layerId, annotation) {
      if (_activeBuses.containsKey(id)) {
        final bus = _activeBuses[id]!;
        Navigator.push(context, MaterialPageRoute(builder: (_) => BusDetailsScreen(bus: bus)));
      }
    });
  }

  void _onStyleLoaded() async {
    _isMapReady = false;
    debugPrint("MAP STYLE LOADED - CLEARING OLD STATE");
    
    _hasCenteredOnBus = false;
    _registeredBusLabels.clear(); // Re-register images since map engine was recreated

    // Load bus_3d image
    try {
      final ByteData data = await rootBundle.load('assets/bus_3d.png');
      final Uint8List bytes = data.buffer.asUint8List();
      await _mapController?.addImage("bus_3d", bytes);
    } catch (e) {
      debugPrint("Error loading bus_3d.png: $e");
    }
    
    // Add empty GeoJSON source for buses
    await _mapController?.addGeoJsonSource("buses_source", {
      "type": "FeatureCollection",
      "features": []
    });

    // Add Symbol Layer for buses
    await _mapController?.addSymbolLayer(
      "buses_source",
      "buses_layer",
      const ml.SymbolLayerProperties(
        iconImage: "bus_3d",
        iconSize: 0.28,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );

    // Add Symbol Layer for bus LABELS
    await _mapController?.addSymbolLayer(
      "buses_source",
      "buses_label_layer",
      const ml.SymbolLayerProperties(
        iconImage: "{labelImage}",
        iconSize: 0.4, // Slightly smaller than bus
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOffset: [0.0, 1.5], // Offset downwards
      ),
    );

    // INJECT DUMMY BUSES (always ensure they exist for the demo)
    final List<String> dummyIds = ["BUS-101", "BUS-202", "BUS-303", "BUS-404"];
    for (int i = 0; i < dummyIds.length; i++) {
      final String id = dummyIds[i];
      if (!_activeBuses.containsKey(id)) {
        final int startIndex = (i * (MapScreen.edsaPoints.length ~/ dummyIds.length)) % MapScreen.edsaPoints.length;
        _busRouteIndices[id] = startIndex;
        _activeBuses[id] = Bus(
          id: id,
          routeName: "EDSA CAROUSEL",
          startTerminal: "Monumento",
          endTerminal: "PITX",
          location: ll.LatLng(MapScreen.edsaPoints[startIndex].latitude, MapScreen.edsaPoints[startIndex].longitude),
          currentStop: MapScreen.edsaPointNames[startIndex],
          nextStop: MapScreen.edsaPointNames[(startIndex + 1) % MapScreen.edsaPoints.length],
          eta: "Calculating...",
          passengerCount: 20 + i,
          standingCount: 5,
          capacity: 50,
          isNorthbound: true,
        );
      }
    }

    await _drawEdsaRoute();
    await _drawStations();
    
    _isMapReady = true;
    
    // Re-start simulation (clears old timer too)
    _startSimulation();
  }


  Future<void> _drawStations() async {
    if (_mapController == null) return;
    final stations = [
      {'name': 'Monumento', 'lat': 14.6575128, 'lng': 120.9840488},
      {'name': 'Bagong Barrio', 'lat': 14.6594371, 'lng': 120.9901416},
      {'name': 'Balintawak', 'lat': 14.6596102, 'lng': 121.0006766},
      {'name': 'Kaingin', 'lat': 14.6585, 'lng': 121.0118},
      {'name': 'Roosevelt', 'lat': 14.6576553, 'lng': 121.0196921},
      {'name': 'North Avenue', 'lat': 14.6521583, 'lng': 121.0322588},
      {'name': 'Quezon Avenue', 'lat': 14.6423458, 'lng': 121.0381488},
      {'name': 'Nepa Q-Mart', 'lat': 14.6300, 'lng': 121.0440},
      {'name': 'Main Avenue', 'lat': 14.6152145, 'lng': 121.0523456},
      {'name': 'Santolan', 'lat': 14.6074212, 'lng': 121.0560824},
      {'name': 'Ortigas', 'lat': 14.5878456, 'lng': 121.0566898},
      {'name': 'Guadalupe', 'lat': 14.5672154, 'lng': 121.0450588},
      {'name': 'Buendia', 'lat': 14.5542, 'lng': 121.0345},
      {'name': 'Ayala', 'lat': 14.5491542, 'lng': 121.0283498},
      {'name': 'Taft', 'lat': 14.5376543, 'lng': 121.0012345},
      {'name': 'Roxas', 'lat': 14.5340, 'lng': 120.9900},
      {'name': 'MOA', 'lat': 14.5360, 'lng': 120.9810},
      {'name': 'Tramo', 'lat': 14.5290, 'lng': 121.0000},
      {'name': 'DFA/Shell/Starbucks', 'lat': 14.5240, 'lng': 120.9920},
      {'name': 'Ayala Malls Manila Bay', 'lat': 14.5190, 'lng': 120.9890},
      {'name': 'PITX', 'lat': 14.5111647, 'lng': 120.9917209},
    ];

    for (var station in stations) {
      final String name = station['name'] as String;
      final bytes = await _createLabelBitmap(name);
      await _mapController!.addImage("label_$name", bytes);

      await _mapController!.addCircle(
        ml.CircleOptions(
          geometry: ml.LatLng(station['lat'] as double, station['lng'] as double),
          circleColor: "#FFD700",
          circleRadius: 6.0,
          circleStrokeColor: "#000000",
          circleStrokeWidth: 2.0,
        ),
      );

      await _mapController!.addSymbol(
        ml.SymbolOptions(
          geometry: ml.LatLng(station['lat'] as double, station['lng'] as double),
          iconImage: "label_$name",
          iconSize: 0.4,
          iconOffset: const Offset(0, -35),
        ),
      );
    }
  }

  Future<void> _drawEdsaRoute() async {
    if (_mapController == null) return;
    await _mapController!.addLine(
      ml.LineOptions(
        geometry: MapScreen.edsaPoints,
        lineColor: "#FFD700",
        lineWidth: 6.0,
        lineOpacity: 0.8,
      ),
    );
  }

  Future<Uint8List> _createLabelBitmap(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final width = textPainter.width + 40;
    final height = textPainter.height + 20;
    final paint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(RRect.fromLTRBR(0, 0, width, height, const Radius.circular(8)), paint);
    textPainter.paint(canvas, const Offset(20, 10));
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isMapView ? _buildMapLayout() : _buildListLayout(),
    );
  }

  Widget _buildMapLayout() {
    return Stack(
      children: [
        ml.MapLibreMap(
          key: ValueKey("map_$_isDarkMap"),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: _onMapTapped,
          onCameraIdle: _onCameraIdle,
          initialCameraPosition: const ml.CameraPosition(
            target: ml.LatLng(14.5995, 120.9842),
            zoom: 12.0,
          ),
          styleString: _styleUrl,
          trackCameraPosition: true,
          myLocationEnabled: true,
        ),
        _buildMapOverlays(),
      ],
    );
  }

  Widget _buildListLayout() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(isMap: false),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildToggleButtons(),
              ],
            ),
          ),
          Expanded(
            child: _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOverlays() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(isMap: true),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildToggleButtons(),
              ],
            ),
          ),
          const Spacer(),
          _buildFloatingButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isMap}) {
    final textColor = isMap ? _overlayTextColor : Colors.black;
    final shadowColor = isMap ? Colors.black.withValues(alpha: 0.5) : Colors.transparent;
    return Center(
      child: Text(
        'EDSA CAROUSEL',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: shadowColor, offset: const Offset(0, 2), blurRadius: isMap ? 4 : 0),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        style: GoogleFonts.outfit(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search bus number...',
          hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMapView = true),
              child: Container(
                decoration: BoxDecoration(color: _isMapView ? Colors.black : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('MAP VIEW', style: GoogleFonts.outfit(color: _isMapView ? const Color(0xFFFFD700) : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMapView = false),
              child: Container(
                decoration: BoxDecoration(color: !_isMapView ? Colors.black : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('LIST VIEW', style: GoogleFonts.outfit(color: !_isMapView ? const Color(0xFFFFD700) : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, right: 24),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: '3d_btn',
              mini: true,
              backgroundColor: _is3D ? const Color(0xFFFFD700) : Colors.black,
              child: Icon(Icons.view_in_ar_outlined, color: _is3D ? Colors.black : const Color(0xFFFFD700)),
              onPressed: () {
                setState(() {
                  _is3D = !_is3D;
                  _mapController?.animateCamera(ml.CameraUpdate.newCameraPosition(ml.CameraPosition(
                    target: _mapController!.cameraPosition!.target,
                    zoom: _mapController!.cameraPosition!.zoom,
                    tilt: _is3D ? 60.0 : 0.0,
                    bearing: _is3D ? -15.0 : 0.0,
                  )));
                });
              },
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'theme_btn',
              mini: true,
              backgroundColor: _isDarkMap ? Colors.white : Colors.black,
              child: Icon(_isDarkMap ? Icons.wb_sunny : Icons.nightlight_round, color: _isDarkMap ? Colors.black : const Color(0xFFFFD700)),
              onPressed: () => setState(() => _isDarkMap = !_isDarkMap),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'loc_btn',
              backgroundColor: Colors.black,
              child: const Icon(Icons.my_location, color: Color(0xFFFFD700)),
              onPressed: () {
                if (_activeBuses.isNotEmpty) {
                  final bus = _activeBuses.values.first;
                  _mapController?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(bus.location.latitude, bus.location.longitude), 16));
                } else {
                  _mapController?.animateCamera(ml.CameraUpdate.newLatLngZoom(const ml.LatLng(14.5995, 120.9842), 12.0));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final buses = _activeBuses.values.toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
        ),
      ),
      child: buses.isEmpty
          ? Center(child: Text('No active buses found.', style: GoogleFonts.outfit(color: Colors.black54, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 100, left: 16, right: 16),
              itemCount: buses.length,
              itemBuilder: (context, index) => _buildBusCard(buses[index]),
            ),
    );
  }

  Widget _buildBusCard(Bus bus) {
    double occupancy = bus.occupancyRate.clamp(0.0, 1.0);
    Color statusColor = occupancy > 0.8 ? const Color(0xFFFF4757) : (occupancy > 0.5 ? const Color(0xFFFFA502) : const Color(0xFF2ED573));
    String statusText = occupancy > 0.8 ? 'CROWDED' : (occupancy > 0.5 ? 'MODERATE' : 'AVAILABLE');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BusDetailsScreen(bus: bus))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(14),
                        ), 
                        child: const Icon(Icons.directions_bus_filled, color: Color(0xFFFFD700), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bus.id, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Colors.black45),
                                const SizedBox(width: 4),
                                Expanded(child: Text('${bus.startTerminal} → ${bus.endTerminal}', style: GoogleFonts.outfit(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusText, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Colors.black12),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(Icons.people_alt_outlined, 'Passengers', '${bus.passengerCount + bus.standingCount}/${bus.capacity}'),
                      if ((bus.passengerCount + bus.standingCount) >= bus.capacity)
                         _buildInfoItem(Icons.warning_amber_rounded, 'Caution', '${(bus.passengerCount + bus.standingCount) - bus.capacity} Standing'),
                      if ((bus.passengerCount + bus.standingCount) < bus.capacity)
                         _buildInfoItem(Icons.event_seat, 'Status', 'Seats Available'),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isMapView = true);
                          _mapController?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(bus.location.latitude, bus.location.longitude), 16.0));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, 
                          foregroundColor: const Color(0xFFFFD700), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.my_location, size: 14),
                            const SizedBox(width: 6),
                            Text('LOCATE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.black45),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.outfit(color: Colors.black45, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
