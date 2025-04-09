import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pago_lote_screen.dart';
import 'editar_lotes_screen.dart';

enum LoteState { libre, seleccionado, ocupado }

class AsignarLoteScreen extends StatefulWidget {
  const AsignarLoteScreen({Key? key}) : super(key: key);

  @override
  State<AsignarLoteScreen> createState() => _AsignarLoteScreenState();
}

class _AsignarLoteScreenState extends State<AsignarLoteScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  // Lógica local de lotes
  List<LoteState> _lotes = [];
  int _loteCount = 0;
  int _lotePrice = 500; // por defecto
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Carga la información de Firestore: loteCount, lotePrice, occupiedLotes
  Future<void> _fetchData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("salas")
          .doc("sala1")
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _loteCount = data["loteCount"] ?? 3;
          _lotePrice = data["lotePrice"] ?? 500;
          // Inicializamos los lotes en "libre"
          _lotes = List.generate(_loteCount, (_) => LoteState.libre);
          // Marcamos como ocupados los que aparecen en occupiedLotes
          List<dynamic> occupiedList = data["occupiedLotes"] ?? [];
          for (var item in occupiedList) {
            if (item is String) {
              // Ej: "Lote 2"
              final numStr = item.replaceAll("Lote ", "");
              final index = int.tryParse(numStr);
              if (index != null && index > 0 && index <= _loteCount) {
                _lotes[index - 1] = LoteState.ocupado;
              }
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = "No se encontró el documento 'sala1' en Firestore.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = "Error cargando datos: $e";
        _isLoading = false;
      });
    }
  }

  /// Alterna un lote si no está ocupado
  void _toggleLote(int index) {
    setState(() {
      if (_lotes[index] == LoteState.ocupado) return;
      if (_lotes[index] == LoteState.libre) {
        _lotes[index] = LoteState.seleccionado;
      } else if (_lotes[index] == LoteState.seleccionado) {
        _lotes[index] = LoteState.libre;
      }
    });
  }

  Color _getColor(LoteState state) {
    switch (state) {
      case LoteState.libre:
        return Colors.grey;
      case LoteState.seleccionado:
        return Colors.pink;
      case LoteState.ocupado:
        return Colors.purple;
    }
  }

  /// Captura el croquis y lo comparte
  Future<void> _captureAndShare() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/lote_map.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)], text: '¡Mira mis lotes!');
      }
    } catch (e) {
      print("Error al compartir: $e");
    }
  }

  /// Al presionar "Siguiente", si hay exactamente 1 lote seleccionado, vamos a la pantalla de pago
  void _goToPago() {
    final selectedIndices = <int>[];
    for (int i = 0; i < _lotes.length; i++) {
      if (_lotes[i] == LoteState.seleccionado) {
        selectedIndices.add(i);
      }
    }

    if (selectedIndices.isEmpty) {
      _showSnack("Selecciona al menos un lote para continuar.");
      return;
    }
    if (selectedIndices.length > 1) {
      _showSnack("Solo puedes apartar 1 lote a la vez.");
      return;
    }

    // Navegar a la pantalla de pago con la info del lote
    final index = selectedIndices.first;
    final loteName = "Lote ${index + 1}";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoLoteScreen(
          loteName: loteName,
          lotePrice: _lotePrice,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asignar lote", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
          ? Center(child: Text(_errorMsg!))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escoge el lote.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Croquis con RepaintBoundary
            RepaintBoundary(
              key: _repaintKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "Carnaval",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Precio: \$$_lotePrice",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    // Muestra todos los lotes en una fila
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _loteCount,
                              (index) => GestureDetector(
                            onTap: () => _toggleLote(index),
                            child: Container(
                              width: 80,
                              height: 150,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5),
                              color: _getColor(_lotes[index]),
                              child: Center(
                                child: Text(
                                  "Lote ${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Leyenda
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendCircle(Colors.purple, "Ocupado"),
                const SizedBox(width: 20),
                _buildLegendCircle(Colors.grey, "Libre"),
                const SizedBox(width: 20),
                _buildLegendCircle(Colors.pink, "Seleccionado"),
              ],
            ),
            const SizedBox(height: 20),
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _captureAndShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Compartir"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditarLotesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Editar lotes"),
                ),
                ElevatedButton(
                  onPressed: _goToPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Siguiente"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendCircle(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text),
      ],
    );
  }
}


