// lib/screens/asignar_sillas.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'editar_filas_columnas_screen.dart';
import 'pago_boletos_screen.dart';

class AsignarSillaScreen extends StatefulWidget {
  final int zoneIndex;
  const AsignarSillaScreen({Key? key, required this.zoneIndex})
      : super(key: key);

  @override
  State<AsignarSillaScreen> createState() => _AsignarSillaScreenState();
}

class _AsignarSillaScreenState extends State<AsignarSillaScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _loading = true;
  String? _error;

  // Configuración de esta zona:
  late int _totalSillas;
  late int _filas;
  late int _columnas;
  late List<int> _precios;               // precios por fila
  late List<String> _seatIds;            // IDs de asiento "A1"… hasta total
  late List<List<bool>> _selMatrix;      // matriz de selección
  List<List<bool>> _occMatrix = [];      // matriz de ocupados

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1) Cargo listas completas de Firestore
      final sSnap = await userRef.collection('config').doc('sillas').get();
      final sData = sSnap.data()!;
      final counts = List<int>.from(sData['counts'] ?? []);
      final rows   = List<int>.from(sData['rows']   ?? []);
      final cols   = List<int>.from(sData['cols']   ?? []);

      // 2) Extraigo sólo mi zona
      final zi = widget.zoneIndex;
      _totalSillas = counts[zi];
      _filas       = rows[zi];
      _columnas    = cols[zi];

      // 3) Genero los IDs de asiento ("A1"…) hasta totalSillas
      _seatIds = List.generate(
        _filas * _columnas,
            (i) => '${String.fromCharCode(65 + i ~/ _columnas)}${(i % _columnas) + 1}',
      ).take(_totalSillas).toList();

      // 4) Cargo precios guardados (o zero-fill)
      final priceDoc = await userRef
          .collection('config')
          .doc('prices')
          .collection('sillas')
          .doc('zona_${zi+1}')
          .get();

      if (priceDoc.exists) {
        final raw = List<dynamic>.from(priceDoc.data()!['filaPrecios'] ?? []);
        _precios = List.generate(
          _filas,
              (r) => (r < raw.length && raw[r] is int) ? raw[r] as int : 0,
        );
      } else {
        // ningún precio definido: llenamos con ceros y luego pedimos al usuario
        _precios = List.filled(_filas, 0);
        // post-frame callback para abrir diálogo
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _promptForPrecios();
        });
      }

      // 5) Inicializo matrices
      _selMatrix = List.generate(_filas, (_) => List.filled(_columnas, false));
      _occMatrix = List.generate(_filas, (_) => List.filled(_columnas, false));

      // 6) Marco ocupados según reservas
      final resSnap = await userRef
          .collection('reservas')
          .where('tipo', isEqualTo: 'silla')
          .where('zona', isEqualTo: zi)
          .get();
      final reserved = <String>{};
      for (var doc in resSnap.docs) {
        final seats = List<dynamic>.from(doc.data()['asientos'] ?? []);
        reserved.addAll(seats.cast<String>());
      }
      for (var seat in reserved) {
        final idx = _seatIds.indexOf(seat);
        if (idx >= 0) {
          final r = idx ~/ _columnas;
          final c = idx % _columnas;
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

  /// Diálogo para capturar el precio de cada fila.
  Future<void> _promptForPrecios() async {
    final controllers = List.generate(
      _filas,
          (r) => TextEditingController(text: _precios[r].toString()),
    );
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Configura precios por fila'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (var r = 0; r < _filas; r++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: controllers[r],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Fila ${String.fromCharCode(65 + r)}',
                      prefixText: '\$',
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1) Leer valores
              final nuevos = controllers.map((c) {
                return int.tryParse(c.text) ?? 0;
              }).toList();

              // 2) Guardar en Firestore
              final uid     = FirebaseAuth.instance.currentUser!.uid;
              final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
              await userRef
                  .collection('config')
                  .doc('prices')
                  .collection('sillas')
                  .doc('zona_${widget.zoneIndex + 1}')
                  .set({'filaPrecios': nuevos});

              // 3) Actualizar estado
              setState(() {
                _precios = nuevos;
              });

              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _toggleSeat(int r, int c) {
    if (_occMatrix[r][c]) return;
    setState(() => _selMatrix[r][c] = !_selMatrix[r][c]);
  }

  Future<void> _captureAndShare() async {
    final boundary = _repaintKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 2.0);
    final bytes    = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer.asUint8List();
    final dir      = await getTemporaryDirectory();
    final file     = await File('${dir.path}/asientos.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Croquis zona ${widget.zoneIndex + 1} con precios por fila',
    );
  }

  // Widget que construye el grid de asientos con numeración completa
  Widget _buildSeatGrid() {
    // Calcula el tamaño basado en el número de filas y columnas
    final maxElements = math.max(_filas, _columnas);
    final double circleSize = maxElements > 10 ? 25.0 : 30.0; // Más pequeño si hay muchos elementos
    final double spacing = circleSize > 25 ? 8.0 : 6.0; // Espaciado proporcional

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Importante para evitar expandir verticalmente
      children: [
        // cabezal gris
        Container(
            width: (_columnas * (circleSize + spacing)) + 40, // Ancho total del grid
            height: 20,
            color: Colors.grey.shade300
        ),
        const SizedBox(height: 12),

        // Numeración columnas (asegurando que abarque todas las columnas)
        Row(
          mainAxisSize: MainAxisSize.min, // Evita expansión horizontal
          children: [
            const SizedBox(width: 40), // Espacio para letras de fila
            for (var c = 0; c < _columnas; c++)
              Container(
                width: circleSize + spacing,
                alignment: Alignment.center,
                child: Text(
                  '${c + 1}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Filas de círculos
        for (var r = 0; r < _filas; r++)
          Row(
            mainAxisSize: MainAxisSize.min, // Evita expansión horizontal
            children: [
              // Letra de fila
              Container(
                width: 40,
                height: circleSize + spacing,
                alignment: Alignment.center,
                child: Text(
                  String.fromCharCode(65 + r),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // Círculos de asientos
              for (var c = 0; c < _columnas; c++)
                if (r * _columnas + c < _totalSillas)
                  Container(
                    width: circleSize,
                    height: circleSize,
                    margin: EdgeInsets.all(spacing / 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _occMatrix[r][c]
                          ? Colors.purple
                          : (_selMatrix[r][c]
                          ? Colors.pinkAccent
                          : Colors.grey),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: InkWell(
                      onTap: () => _toggleSeat(r, c),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  )
                else
                  SizedBox(width: circleSize + spacing),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    // Calcular subtotal y lista seleccionados
    int subtotal = 0, painted = 0;
    final selList = <String>[];
    for (var r = 0; r < _filas; r++) {
      for (var c = 0; c < _columnas; c++) {
        if (painted >= _seatIds.length) break;
        if (_selMatrix[r][c]) {
          selList.add(_seatIds[painted]);
          subtotal += _precios[r];
        }
        painted++;
      }
    }
    final total = subtotal;

    // Calcula la altura ideal para el contenedor basado en el número de filas
    final double containerHeight = math.min(400, math.max(300, _filas * 40.0));

    return Scaffold(
      appBar: AppBar(
        title: Text('Sillas zona ${widget.zoneIndex + 1}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Escoge los asientos.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ──────────────────────────────────
          // Todo el croquis y precios queda dentro del RepaintBoundary:
          RepaintBoundary(
            key: _repaintKey,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min, // Importante para evitar expansión vertical
                    children: [
                      // croquis con InteractiveViewer para zoom y pan
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            mainAxisSize: MainAxisSize.min, // Importante para evitar expansión vertical
                            children: [
                              // Envolvemos el grid en InteractiveViewer y SingleChildScrollView
                              SizedBox(
                                height: containerHeight, // Altura dinámica basada en número de filas
                                child: InteractiveViewer(
                                  boundaryMargin: const EdgeInsets.all(40.0),
                                  minScale: 0.2,
                                  maxScale: 2.0,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical, // Permitir scroll vertical
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal, // Permitir scroll horizontal
                                      child: _buildSeatGrid(),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              const Row(children: [
                                _LegendBox(color: Colors.purple, label: 'Ocupado'),
                                SizedBox(width: 12),
                                _LegendBox(color: Colors.grey, label: 'Libre'),
                                SizedBox(width: 12),
                                _LegendBox(color: Colors.pinkAccent, label: 'Seleccionado'),
                              ]),
                            ]),
                      ),

                      const SizedBox(height: 20),

                      // precios por fila + totales
                      const Text('Precios por fila:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (var r = 0; r < _filas; r++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                              'Fila ${String.fromCharCode(65 + r)}: \$${_precios[r]}'),
                        ),

                      const SizedBox(height: 12),
                      Text('Asientos: ${selList.join(', ')}'),
                      Text('Subtotal: \$$subtotal'),
                      Text('Total: \$$total'),
                    ]),
              ),
            ),
          ),
          // ──────────────────────────────────

          const SizedBox(height: 20),
          Wrap(spacing: 8, children: [
            ElevatedButton.icon(
              onPressed: _captureAndShare,
              icon: const Icon(Icons.share, size: 18, color: Colors.white),
              label:
              const Text('Compartir', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A0F4D),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditarFilasColumnasScreen(
                        zoneIndex: widget.zoneIndex),
                  ),
                );
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Editar sillas'),
            ),
            ElevatedButton.icon(
              onPressed: selList.isEmpty
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PagoBoletosScreen(
                      nombreCliente: '',
                      apellidoCliente: '',
                      asientosSeleccionados: selList,
                      total: total,
                      zona: widget.zoneIndex,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Siguiente'),
            ),
          ]),
        ]),
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