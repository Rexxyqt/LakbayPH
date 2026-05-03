import 'package:latlong2/latlong.dart';

enum StopStatus { passed, current, upcoming }

class BusStop {
  final String name;
  final LatLng location;
  final StopStatus status;
  final String? arrivalTime;

  BusStop({
    required this.name,
    required this.location,
    required this.status,
    this.arrivalTime,
  });
}
