import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PassengerMonitorApp());
}

class PassengerMonitorApp extends StatelessWidget {
  const PassengerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LakbayPH Bus Tracking',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          primary: const Color(0xFFFFD700),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}


