import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bus.dart';
import '../models/bus_stop.dart';

class BusDetailsScreen extends StatelessWidget {
  final Bus bus;

  const BusDetailsScreen({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          bus.id,
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteCard(),
            const SizedBox(height: 12),
            _buildLiveTrackingCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildEtaCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildCapacityCard()),
              ],
            ),
            const SizedBox(height: 12),
            _buildPassengerCountCard(),
            const SizedBox(height: 12),
            _buildStopSequenceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EDSA CAROUSEL',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bus.startTerminal} - ${bus.endTerminal}',
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            bus.isNorthbound ? 'Northbound' : 'Southbound',
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, size: 16, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                'LIVE TRACKING',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'CURRENT LOCATION',
            style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 8, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.green),
              const SizedBox(width: 8),
              ValueListenableBuilder<String>(
                valueListenable: bus.currentStopNotifier,
                builder: (context, stop, _) => Text(
                  stop,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Next Stop',
            style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 8, fontWeight: FontWeight.bold),
          ),
          ValueListenableBuilder<String>(
            valueListenable: bus.nextStopNotifier,
            builder: (context, stop, _) => Text(
              stop,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: bus.etaNotifier,
            builder: (context, eta, _) => Text(
              'ETA: $eta',
              style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700), // Yellow from design
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Time Arrival',
            style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold),
          ),
          ValueListenableBuilder<String>(
            valueListenable: bus.etaNotifier,
            builder: (context, eta, _) => Text(
              eta,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacity',
            style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold),
          ),
          Text(
            '${bus.capacity}',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCountCard() {
    return ValueListenableBuilder<int>(
      valueListenable: bus.passengerCountNotifier,
      builder: (context, count, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LIVE PASSENGER COUNT',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                  Text(
                    count > (bus.capacity * 0.8) ? 'HIGH' : 'NORMAL',
                    style: GoogleFonts.outfit(
                      color: count > (bus.capacity * 0.8) ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: bus.passengerCountNotifier,
                builder: (context, seated, _) => ValueListenableBuilder<int>(
                  valueListenable: bus.standingCountNotifier,
                  builder: (context, standing, _) {
                    final total = seated + standing;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$total',
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PASSENGERS',
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: bus.passengerCountNotifier,
                builder: (context, seated, _) => ValueListenableBuilder<int>(
                  valueListenable: bus.standingCountNotifier,
                  builder: (context, standing, _) {
                    final total = seated + standing;
                    final occupancy = (total / (bus.capacity > 0 ? bus.capacity : 1) * 100).toInt();
                    return Text(
                      '$occupancy% of seated capacity',
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: bus.passengerCountNotifier,
                      builder: (context, seated, _) => _buildSubStat('Seated', '$seated / ${bus.capacity}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: bus.standingCountNotifier,
                      builder: (context, standing, _) => _buildSubStat('Standing', '$standing'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: bus.passengerCountNotifier,
                builder: (context, seated, _) => ValueListenableBuilder<int>(
                  valueListenable: bus.standingCountNotifier,
                  builder: (context, standing, _) {
                    final total = seated + standing;
                    final progress = (total / (bus.capacity > 0 ? bus.capacity : 1)).clamp(0.0, 1.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 8, color: Colors.grey),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSequenceCard() {
    final allStops = [
      'Monumento', 'Bagong Barrio', 'Balintawak', 'Kaingin', 'Roosevelt', 
      'North Avenue', 'Quezon Avenue', 'Nepa Q-Mart', 'Main Avenue', 'Santolan', 
      'Ortigas', 'Guadalupe', 'Buendia', 'Ayala', 'Taft', 'Roxas', 'MOA', 
      'Roxas Junction', 'Tramo', 'DFA/Shell/Starbucks', 'Ayala Malls Manila Bay', 'PITX'
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STOP SEQUENCE',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: bus.currentStopNotifier,
            builder: (context, currentStop, _) {
              int currentIndex = allStops.indexOf(currentStop);
              int nextIndex = allStops.indexOf(bus.nextStop);
              if (currentIndex == -1) currentIndex = 0;
              if (nextIndex == -1) nextIndex = currentIndex + 1;

              // Determine route direction from current vs next stop
              bool goingSouth = true;
              if (nextIndex < currentIndex && !(currentIndex == allStops.length - 1 && nextIndex == 0)) {
                goingSouth = false;
              }

              List<String> displayStops = goingSouth ? List.from(allStops) : List.from(allStops.reversed);
              int currentDisplayIndex = displayStops.indexOf(currentStop);
              if (currentDisplayIndex == -1) currentDisplayIndex = 0;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayStops.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == currentDisplayIndex;
                  final isPassed = index < currentDisplayIndex;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(
                            isCurrent ? Icons.radio_button_checked : (isPassed ? Icons.check_circle : Icons.radio_button_off),
                            size: 16,
                            color: isPassed ? Colors.grey : Colors.black,
                          ),
                          if (index != displayStops.length - 1)
                            Container(
                              width: 2,
                              height: 30,
                              color: isPassed ? Colors.grey : Colors.black,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayStops[index].toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.w900 : (isPassed ? FontWeight.normal : FontWeight.bold),
                              color: isCurrent ? Colors.black : (isPassed ? Colors.grey : Colors.black87),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CURRENT LOCATION',
                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
