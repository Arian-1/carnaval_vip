import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asignar_lote_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Función para obtener el nombre del usuario desde Firestore
  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['nombre'] ?? "Usuario";
      }
    }
    return "Usuario";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userName = snapshot.data ?? "Usuario";
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "CARNAVAL VIP",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF5E1A47),
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF5E1A47)),
                  accountName: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  accountEmail: const Text(""),
                ),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text("Croquis"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text("Mi cuenta"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.event_seat),
                  title: const Text("Asignar sillas"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text("Asignar lote"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AsignarLoteScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text("Clientes"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text("Ventas"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text("Proveedores"),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text("Salir"),
                  onTap: () {},
                ),
                const AboutListTile(
                  icon: Icon(Icons.help),
                  child: Text("Ayuda"),
                  applicationName: "Carnaval VIP",
                  applicationVersion: "1.0.0",
                  applicationLegalese: "© 2025",
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "¡Bienvenid@, $userName!",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Carnaval 2025",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCroquis(context),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    onPressed: () {
                      // Acción para descargar el croquis
                    },
                    child: const Text(
                      "Descargar croquis",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Se añade BuildContext para poder usar Navigator en los recuadros
  Widget _buildCroquis(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionBox(context, "Sillas", 200, 100, const Color(0xFF8B348C)),
              const SizedBox(width: 10),
              _buildSectionBox(context, "Lotes", 100, 100, const Color(0xFFA24DAF)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSectionBox(context, "Tarima", 200, 60, const Color(0xFFBA72C4)),
              const SizedBox(width: 10),
              _buildSectionBox(context, "Zona comercial", 100, 60, const Color(0xFFD989E2)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSectionBox(context, "Baños", 80, 40, const Color(0xFFE6A2EB)),
            ],
          ),
        ],
      ),
    );
  }

  // Se recibe el BuildContext como primer parámetro para poder navegar
  Widget _buildSectionBox(BuildContext context, String title, double width, double height, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == "Lotes") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AsignarLoteScreen()),
          );
        }
      },
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


