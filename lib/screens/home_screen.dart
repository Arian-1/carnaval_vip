// lib/screens/home_screen.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/layout_draggable.dart';
import 'asignar_sillas.dart';
import 'asignar_lote_screen.dart';
import 'asignar_tarima_screen.dart';
import 'clientes_screen.dart';
import 'proveedores_screen.dart';
import 'ventas_screen.dart';
import 'manage_zones_screen.dart'; // Importamos la nueva pantalla

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _croquisKey = GlobalKey();
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    // Esperar al primer frame para tener MediaQuery disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLayout();
    });
  }

  Future<void> _ensureLayout() async {
    final uid       = FirebaseAuth.instance.currentUser!.uid;
    final userRef   = FirebaseFirestore.instance.collection('users').doc(uid);
    final layoutCol = userRef.collection('layout');

    // Si ya hay layout, saltamos
    final existing = await layoutCol.limit(1).get();
    if (existing.docs.isNotEmpty) {
      setState(() => _initializing = false);
      return;
    }

    // 1) Leer config del wizard
    final setupSnap   = await userRef.collection('config').doc('setup').get();
    final setup       = setupSnap.data() as Map<String,dynamic>? ?? {};
    final zs           = (setup['zonaSillas']  ?? 0) as int;
    final zl           = (setup['zonesLotes']  ?? 0) as int;
    final zt           = (setup['tarimas']     ?? 0) as int;
    final extras       = List<String>.from(setup['extras'] ?? []);

    // 2) Preparar wrapping
    final screenW  = MediaQuery.of(context).size.width;
    final horizPad = 16.0 * 2; // Padding cuerpo
    final cardPad  = 16.0 * 2; // Padding interior Card
    final maxWidth = screenW - horizPad - cardPad;
    const gap     = 16.0;      // Separación entre zonas

    double x = 0, y = 0, rowH = 0;

    Future<void> placeZone(String docId, String name) async {
      const w = 100.0, h = 80.0; // Tamaño preliminar de vista previa
      if (x + w > maxWidth) {
        x = 0;
        y += rowH + gap;
        rowH = 0;
      }
      await layoutCol.doc(docId).set({
        'name': name,
        'position': {'x': x, 'y': y},
        'size':     {'width': w, 'height': h},
      });
      x += w + gap;
      rowH = max(rowH, h);
    }

    // 3) Crear documentos de layout
    for (var i = 0; i < zs; i++) {
      await placeZone('sillas_${i+1}', 'Sillas ${i+1}');
    }
    for (var i = 0; i < zl; i++) {
      await placeZone('lotes_${i+1}', 'Lotes ${i+1}');
    }
    for (var i = 0; i < zt; i++) {
      await placeZone('tarimas_${i+1}', 'Tarimas ${i+1}');
    }
    for (var tipo in extras) {
      await placeZone(tipo.toLowerCase(), tipo);
    }

    setState(() => _initializing = false);
  }

  Future<void> _captureAndShareCroquis() async {
    try {
      final boundary = _croquisKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image    = await boundary.toImage(pixelRatio: 2.0);
      final bytes    = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer.asUint8List();
      final dir   = await getTemporaryDirectory();
      final file  = await File('${dir.path}/croquis.png').create();
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Mi croquis de Carnaval');
    } catch (e) {
      debugPrint('Error compartiendo croquis: $e');
    }
  }

  void _navigate(String id) {
    // Mejorado para soportar cualquier número de zona
    if (id.startsWith('sillas_')) {
      final idx = int.parse(id.split('_')[1]) - 1;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarSillaScreen(zoneIndex: idx),
        ),
      );
    } else if (id.startsWith('lotes_')) {
      final idx = int.parse(id.split('_')[1]) - 1;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarLoteScreen(zoneIndex: idx),
        ),
      );
    } else if (id.startsWith('tarimas_')) {
      final idx = int.parse(id.split('_')[1]) - 1;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarTarimaScreen(zoneIndex: idx),
        ),
      );
    }
  }

  Color _colorById(String id) {
    if (id.startsWith('sillas'))  return Colors.purple;
    if (id.startsWith('lotes'))   return Colors.redAccent;
    if (id.startsWith('tarimas')) return Colors.pink.shade600;
    return Colors.pinkAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final uid       = FirebaseAuth.instance.currentUser!.uid;
    final userDoc   = FirebaseFirestore.instance.collection('users').doc(uid);
    final layoutCol = userDoc.collection('layout');

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Carnaval VIP', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF5A0F4D)),
            child: Text('Menú',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),

          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Proveedores'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProveedoresScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('Zonas'),
            onTap: () {
              Navigator.pop(context);
              // Navegamos a la nueva pantalla de gestión de zonas
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageZonesScreen()))
                  .then((_) {
                // Cuando volvamos, actualizamos la vista para reflejar cambios
                setState(() {});
              });
            },
          ),

          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Ventas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VentasScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/onboarding', (_) => false);
            },
          ),
        ]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _croquisKey,
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: userDoc.get(),
                          builder: (c, usnap) {
                            if (!usnap.hasData) return const SizedBox();
                            final data = usnap.data!.data() as Map<String, dynamic>;
                            return Text('Bienvenido ${data['nombre']}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold));
                          },
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text('Carnaval 2025',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900)),
                        ),
                        const Divider(),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: layoutCol.snapshots(),
                            builder: (c, snap) {
                              if (!snap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return InteractiveViewer(
                                boundaryMargin: const EdgeInsets.all(50),
                                minScale: 0.5,
                                maxScale: 3.0,
                                child: Stack(
                                  children: snap.data!.docs.map((doc) {
                                    final d = doc.data()! as Map<String, dynamic>;
                                    return LayoutDraggable(
                                      docRef: layoutCol.doc(doc.id),
                                      data: d,
                                      color: _colorById(doc.id),
                                      onTap: () => _navigate(doc.id),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageZonesScreen())
                    ).then((_) => setState(() {}));
                  },
                  icon: const Icon(Icons.dashboard_customize, size: 20, color: Colors.white),
                  label: const Text('Gestionar Zonas', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A0F4D),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _captureAndShareCroquis,
                  icon: const Icon(Icons.download, size: 20, color: Colors.white),
                  label: const Text('Descargar croquis', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D0909),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}