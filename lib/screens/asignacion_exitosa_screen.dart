import 'package:flutter/material.dart';

class AsignacionExitosaScreen extends StatelessWidget {
  const AsignacionExitosaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pantalla de confirmación
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¡Genial!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Se ha asignado correctamente"),
              const SizedBox(height: 20),
              Icon(Icons.check_circle, color: Colors.purple.shade300, size: 50),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Regresa a la pantalla principal (o la que desees)
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D0909),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("Regresar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

