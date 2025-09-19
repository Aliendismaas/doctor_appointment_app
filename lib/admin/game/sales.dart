import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Sales extends StatelessWidget {
  const Sales({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sales', style: GoogleFonts.pacifico()),
        backgroundColor: const Color.fromARGB(255, 9, 143, 67),
      ),
      body: Center(child: Text("Sales report")),
    );
  }
}
