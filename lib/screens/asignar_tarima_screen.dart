// lib/screens/asignar_tarima_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pago_tarima_screen.dart';
import 'editar_tarimas_screen.dart';

class AsignarTarimaScreen extends StatefulWidget {
  final int zoneIndex;
  const AsignarTarimaScreen({Key? key, required this.zoneIndex})
      : super(key: key);

  @override
  State<AsignarTarimaScreen> createState() => _AsignarTarimaScreenState();
}

class _AsignarTarimaScreenState extends State<AsignarTarimaScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _loading = true;
  String? _error;

  late int _rows, _cols, _count;
  int? _price;
  late List<String> _tarimaIds;
  late List<List<bool>> _selMatrix;
  late List<List<bool>> _occMatrix;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _loadConfig() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1) Leer config/tarimas → zones
      final docSnap = await userRef.collection('config').doc('tarimas').get();
      final data    = docSnap.data() as Map<String, dynamic>? ?? {};

      // 2) Extraer filas/cols/count
      final rawZones = data['zones'];
      Map<String, dynamic> zoneMap = {};
      if (rawZones is Map) {
        zoneMap = Map<String, dynamic>.from(
          rawZones['${widget.zoneIndex}'] as Map? ?? {},
        );
      } else if (rawZones is List) {
        if (widget.zoneIndex < rawZones.length && rawZones[widget.zoneIndex] is Map) {
          zoneMap = Map<String, dynamic>.from(rawZones[widget.zoneIndex]);
        }
      }

      if (zoneMap.isNotEmpty) {
        _rows  = _parseInt(zoneMap['rows']);
        _cols  = _parseInt(zoneMap['cols']);
        _count = _parseInt(zoneMap['count']);
      } else {
        final rowsArr   = List<int>.from(data['rows']   ?? []);
        final colsArr   = List<int>.from(data['cols']   ?? []);
        final countsArr = List<int>.from(data['counts'] ?? []);
        _rows  = widget.zoneIndex < rowsArr.length   ? rowsArr[widget.zoneIndex]   : 1;
        _cols  = widget.zoneIndex < colsArr.length   ? colsArr[widget.zoneIndex]   : 1;
        _count = widget.zoneIndex < countsArr.length ? countsArr[widget.zoneIndex] : 1;
      }

      // 3) IDs de tarima estilo “A1”, “A2”, … “B1”, …, hasta _count
      _tarimaIds = List.generate(_rows * _cols, (i) {
        final r = i ~/ _cols;  // fila 0,1,2…
        final c = i %  _cols;  // col 0,1,2…
        return '${String.fromCharCode(65 + r)}${c + 1}';
      }).take(_count).toList();

      // 4) Precio si existe
      final pSnap = await userRef
          .collection('config')
          .doc('prices')
          .collection('tarimas')
          .doc('zona_${widget.zoneIndex+1}')
          .get();
      if (pSnap.exists) {
        final p = pSnap.data()!['precio'];
        if (p is num) _price = p.toInt();
      }

      // 5) Inicializar matrices
      _selMatrix = List.generate(_rows, (_) => List.filled(_cols, false));
      _occMatrix = List.generate(_rows, (_) => List.filled(_cols, false));

      // 6) Marcar ocupados según reservas
      final resSnap = await userRef
          .collection('reservas')
          .where('tipo', isEqualTo: 'tarima')
          .where('zona', isEqualTo: widget.zoneIndex)
          .get();
      final reserved = <String>{};
      for (var d in resSnap.docs) {
        final item = d.data()['item'];
        if (item is String) reserved.add(item);
      }
      for (var name in reserved) {
        final idx = _tarimaIds.indexOf(name);
        if (idx >= 0) {
          final r = idx ~/ _cols;
          final c = idx %  _cols;
          _occMatrix[r][c] = true;
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _promptForPrice() async {
    final ctrl = TextEditingController(text: (_price ?? 0).toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio zona ${widget.zoneIndex+1}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final v   = int.tryParse(ctrl.text) ?? 0;
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users').doc(uid)
                  .collection('config').doc('prices')
                  .collection('tarimas').doc('zona_${widget.zoneIndex+1}')
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

  void _toggle(int r, int c) {
    if (_occMatrix[r][c]) return;
    setState(() => _selMatrix[r][c] = !_selMatrix[r][c]);
  }

  Future<void> _captureAndShare() async {
    final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 2.0);
    final bytes    = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();
    final dir      = await getTemporaryDirectory();
    final file     = await File('${dir.path}/tarimas.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: '¡Mira mis tarimas y precios!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text('Error: $_error')));
    if (_price == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForPrice());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final freeColor = Colors.grey.shade400;
    final selList   = <String>[];
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final idx = r * _cols + c;
        if (idx < _count && _selMatrix[r][c]) selList.add(_tarimaIds[idx]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Tarimas zona ${widget.zoneIndex+1}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Escoge la tarima.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Esta sección se captura (incluye precio, grid y leyenda)
          RepaintBoundary(
            key: _repaintKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Precio dentro de la imagen
                Text('Precio: \$$_price',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // “Escenario”
                Container(height: 20, color: Colors.grey.shade300),
                const SizedBox(height: 12),

                // Numeración columnas
                Row(children: [
                  const SizedBox(width: 24),
                  for (var c = 0; c < _cols; c++)
                    Expanded(child: Center(child: Text('${c+1}'))),
                ]),
                const SizedBox(height: 8),

                // Filas de círculos
                for (var r = 0; r < _rows; r++)
                  Row(children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + r),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    for (var c = 0; c < _cols; c++)
                      if (r * _cols + c < _count)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _toggle(r, c),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _occMatrix[r][c]
                                    ? Colors.purple
                                    : (_selMatrix[r][c]
                                    ? Colors.pinkAccent
                                    : freeColor),
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                  ]),
                const SizedBox(height: 12),

                // Leyenda
                const Row(children: [
                  _Legend(color: Colors.purple, label: 'Ocupado'),
                  SizedBox(width: 12),
                  _Legend(color: Colors.grey, label: 'Libre'),
                  SizedBox(width: 12),
                  _Legend(color: Colors.pinkAccent, label: 'Seleccionado'),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 20),
          // Botones fuera de la imagen
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: _captureAndShare,
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditarTarimasScreen(zoneIndex: widget.zoneIndex),
                ),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Editar tarimas'),
            ),
            ElevatedButton.icon(
              onPressed: selList.isEmpty
                  ? null
                  : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PagoTarimaScreen(
                    tarimaName: selList.first,
                    tarimaPrice: _price!,
                    zona: widget.zoneIndex,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext c) => Row(children: [
    Container(width: 16, height: 16, color: color),
    const SizedBox(width: 4),
    Text(label),
  ]);
}
