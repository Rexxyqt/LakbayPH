import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../config.dart';
import 'driver_dashboard.dart';

class RegisterBusScreen extends StatefulWidget {
  const RegisterBusScreen({super.key});

  @override
  State<RegisterBusScreen> createState() => _RegisterBusScreenState();
}

class _RegisterBusScreenState extends State<RegisterBusScreen> {
  final _driverIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _busNumberController = TextEditingController();
  final _plateController = TextEditingController();
  final _capacityController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/register_bus'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': _driverIdController.text,
          'driver_name': _nameController.text,
          'phone': _phoneController.text,
          'bus_number': _busNumberController.text,
          'plate_number': _plateController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 50,
          'pin': _pinController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DriverDashboard()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection Error'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'UNIT REGISTRATION',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register Your Unit',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the details of your bus unit to start tracking passenger occupancy.',
              style: GoogleFonts.outfit(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildField('DRIVER ID / EMAIL', 'e.g. juan.delacruz@lakbayph.com', _driverIdController, Icons.alternate_email),
            _buildField('DRIVER NAME', 'e.g. Juan Dela Cruz', _nameController, Icons.person_outline),
            _buildField('PHONE NUMBER', 'e.g. 09051234567', _phoneController, Icons.phone_android_outlined),
            _buildField('BUS NUMBER', 'e.g. BUS-4021', _busNumberController, Icons.directions_bus_outlined),
            _buildField('PLATE NUMBER', 'e.g. ABC 1234', _plateController, Icons.vignette_outlined),
            _buildField('SEATED CAPACITY', 'e.g. 50', _capacityController, Icons.event_seat_outlined),
            _buildField('LOGIN PIN (4 DIGITS)', 'e.g. 1234', _pinController, Icons.lock_outline, isNumeric: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFFFFD700))
                    : Text(
                        'COMPLETE REGISTRATION',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            obscureText: isNumeric, // Mask PIN if it's numeric
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.black, size: 20),
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
