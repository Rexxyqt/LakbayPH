import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class Bus {
  final String id;
  final String routeName;
  final String startTerminal;
  final String endTerminal;
  LatLng location;
  final ValueNotifier<String> currentStopNotifier;
  final ValueNotifier<String> nextStopNotifier;
  final ValueNotifier<String> etaNotifier;
  final ValueNotifier<int> passengerCountNotifier;
  final ValueNotifier<int> standingCountNotifier;
  final int capacity;
  final bool isNorthbound;

  Bus({
    required this.id,
    required this.routeName,
    required this.startTerminal,
    required this.endTerminal,
    required this.location,
    required String currentStop,
    required String nextStop,
    required String eta,
    required int passengerCount,
    required int standingCount,
    required this.capacity,
    this.isNorthbound = true,
  })  : currentStopNotifier = ValueNotifier<String>(currentStop),
        nextStopNotifier = ValueNotifier<String>(nextStop),
        etaNotifier = ValueNotifier<String>(eta),
        passengerCountNotifier = ValueNotifier<int>(passengerCount),
        standingCountNotifier = ValueNotifier<int>(standingCount);

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] ?? json['bus_id'] ?? json['bus_number'] ?? 'UNKNOWN',
      routeName: json['routeName'] ?? 'EDSA CAROUSEL',
      startTerminal: json['startTerminal'] ?? 'Monumento',
      endTerminal: json['endTerminal'] ?? 'PITX',
      location: LatLng(
        json['location']?['latitude'] ?? json['latitude'] ?? 14.5995,
        json['location']?['longitude'] ?? json['longitude'] ?? 120.9842,
      ),
      currentStop: json['currentStop'] ?? 'N/A',
      nextStop: json['nextStop'] ?? 'N/A',
      eta: json['eta'] ?? 'Live',
      passengerCount: json['passengerCount'] ?? json['seated'] ?? 0,
      standingCount: json['standingCount'] ?? json['standing'] ?? 0,
      capacity: json['capacity'] ?? 50,
      isNorthbound: json['isNorthbound'] ?? true,
    );
  }

  int get passengerCount => passengerCountNotifier.value;
  set passengerCount(int value) => passengerCountNotifier.value = value;

  int get standingCount => standingCountNotifier.value;
  set standingCount(int value) => standingCountNotifier.value = value;

  String get currentStop => currentStopNotifier.value;
  set currentStop(String value) => currentStopNotifier.value = value;

  String get nextStop => nextStopNotifier.value;
  set nextStop(String value) => nextStopNotifier.value = value;

  String get eta => etaNotifier.value;
  set eta(String value) => etaNotifier.value = value;

  double get occupancyRate => (passengerCount + standingCount) / capacity;
}
