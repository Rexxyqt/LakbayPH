import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'map_screen.dart';
import 'driver/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFFE135),
              Colors.white,
            ],
            stops: [0.0, 0.3, 0.6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_bus, color: Color(0xFFFFD700), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'LAKBAYPH',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Text(
                  'Your Journey,\nSimplified.',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose your path to get started with real-time tracking.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 60),
                _buildOption(
                  context,
                  'I AM A COMMUTER',
                  'Find and track buses in real-time',
                  Icons.map_outlined,
                  const Color(0xFF000000),
                  const Color(0xFFFFD700),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
                ),
                const SizedBox(height: 20),
                _buildOption(
                  context,
                  'I AM A DRIVER',
                  'Sign in or Register your bus unit',
                  Icons.drive_eta_outlined,
                  const Color(0xFFFFD700),
                  const Color(0xFF000000),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverLoginScreen())),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'v1.0.2 • Built for LakbayPH',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor == Colors.black ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: bgColor == Colors.black ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: bgColor == Colors.black ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: bgColor == Colors.black ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
