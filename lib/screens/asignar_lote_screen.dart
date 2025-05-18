// lib/screens/asignar_lote_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'editar_lotes_screen.dart';

import 'pago_lote_screen.dart';

class AsignarLoteScreen extends StatefulWidget {
  final int zoneIndex;
  const AsignarLoteScreen({Key? key, required this.zoneIndex})
      : super(key: key);

  @override
  State<AsignarLoteScreen> createState() => _AsignarLoteScreenState();
}

class _AsignarLoteScreenState extends State<AsignarLoteScreen> {
  bool _loading = true;
  String? _error;

  int _count = 0;
  int? _price;
  late List<bool> _occupied;
  late List<bool> _selected;

  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1) ¿Cuántos lotes hay en esta zona?
      final lotesSnap = await userRef.collection('config').doc('lotes').get();
      final lotesData = lotesSnap.data() as Map<String,dynamic>? ?? {};
      final counts    = List<int>.from(lotesData['counts'] ?? []);
      _count = widget.zoneIndex < counts.length
          ? counts[widget.zoneIndex]
          : 1;

      // 2) Precio guardado (si existe)
      final priceSnap = await userRef
          .collection('config')
          .doc('prices')
          .collection('lotes')
          .doc('zona_${widget.zoneIndex + 1}')
          .get();
      if (priceSnap.exists) {
        final p = priceSnap.data()!['precio'];
        if (p is num) _price = p.toInt();
      }

      // 3) ¿Cuáles ya están reservados? (colección reservas)
      final resSnap = await userRef
          .collection('reservas')
          .where('tipo', isEqualTo: 'lote')
          .get();
      final ocupados = resSnap.docs
          .map((d) => d.data())
          .where((m) =>
      m['zona'].toString() == (widget.zoneIndex + 1).toString())
          .map((m) => m['item'] as String)
          .toSet();

      _occupied = List<bool>.generate(
        _count,
            (i) => ocupados.contains('Lote ${i + 1}'),
      );

      // 4) estado de selección inicial (todos false)
      _selected = List<bool>.filled(_count, false);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _promptForPrecio() async {
    final ctrl = TextEditingController(text: (_price ?? 0).toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio zona ${widget.zoneIndex + 1}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text) ?? 0;
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users').doc(uid)
                  .collection('config').doc('prices')
                  .collection('lotes').doc('zona_${widget.zoneIndex + 1}')
                  .set({'precio': v});
              setState(() => _price = v);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _toggle(int i) {
    if (_occupied[i]) return; // no permitimos desocupar
    setState(() => _selected[i] = !_selected[i]);
  }

  Future<void> _captureAndShare() async {
    final boundary = _repaintKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 2.0);
    final bytes    = (await image.toByteData(
        format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();
    final dir      = await getTemporaryDirectory();
    final file     = await File('${dir.path}/lotes.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: '¡Mira mis lotes y precios!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }
    if (_price == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForPrecio());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final freeColor = Colors.grey.shade400;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lotes zona ${widget.zoneIndex + 1}'),
        backgroundColor: const Color(0xFF5A0F4D),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white, // fondo blanco en la imagen
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escoge el lote.',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Precio (solo una vez)
                    Text('Precio: \$$_price',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    // Croquis horizontal
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _count,
                        itemBuilder: (_, i) {
                          final isOcc = _occupied[i];
                          final isSel = _selected[i];
                          final bg = isOcc
                              ? Colors.purple
                              : isSel
                              ? Colors.pinkAccent
                              : freeColor;
                          return GestureDetector(
                            onTap: () => _toggle(i),
                            child: Container(
                              width: 100,
                              margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: bg,
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    'Lote ${i + 1}',
                                    style: TextStyle(
                                      color: (isOcc || isSel)
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Leyenda
                    Row(children: [
                      _LegendBox(color: Colors.purple, label: 'Ocupado'),
                      const SizedBox(width: 16),
                      _LegendBox(color: freeColor, label: 'Libre'),
                      const SizedBox(width: 16),
                      _LegendBox(color: Colors.pinkAccent, label: 'Seleccionado'),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Botones (no se incluyen en la imagen)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _captureAndShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditarLotesScreen(
                          zoneIndex: widget.zoneIndex,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar lotes'),
                ),
                ElevatedButton.icon(
                  onPressed: _selected.every((s) => !s)
                      ? null
                      : () {
                    final idx = _selected.indexWhere((s) => s) + 1;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagoLoteScreen(
                          loteName: 'Lote $idx',
                          lotePrice: _price!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendBox({required this.color, required this.label, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 16, height: 16, color: color),
    const SizedBox(width: 4),
    Text(label),
  ]);
}
