import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pago_boletos_screen.dart';
import 'editar_filas_columnas_screen.dart';

class AsignarSillaScreen extends StatefulWidget {
  const AsignarSillaScreen({Key? key}) : super(key: key);

  @override
  _AsignarSillaScreenState createState() => _AsignarSillaScreenState();
}

class _AsignarSillaScreenState extends State<AsignarSillaScreen> {
  // Key para capturar el croquis (RepaintBoundary)
  final GlobalKey _repaintKey = GlobalKey();

  // Estado local de selección de asientos (inicialmente 3x10, se ajusta cuando Firestore cambia)
  List<List<bool>> seatStatus = List.generate(3, (row) => List.generate(10, (col) => false));

  /// Alterna la selección de un asiento, siempre que no esté ocupado.
  void toggleSeat(int row, int col, Set<String> occupiedSet) {
    String seatId = "${String.fromCharCode(65 + row)}${col + 1}";
    if (!occupiedSet.contains(seatId)) {
      setState(() {
        seatStatus[row][col] = !seatStatus[row][col];
      });
    }
  }

  /// Captura el croquis envuelto en el RepaintBoundary y lo comparte.
  Future<void> _captureAndSharePng() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/seat_map.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)], text: '¡Mira mis asientos!');
      }
    } catch (e) {
      print("Error al capturar y compartir: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CARNAVAL VIP", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("salas").doc("sala1").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Datos de Firestore
          Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;

          // Cantidad dinámica de filas y columnas
          int rowCount = data['rowCount'] ?? 3;
          int colCount = data['colCount'] ?? 10;

          // Ajustar seatStatus si el tamaño cambió
          if (seatStatus.length != rowCount ||
              (seatStatus.isNotEmpty && seatStatus[0].length != colCount)) {
            seatStatus = List.generate(rowCount, (r) => List.generate(colCount, (c) => false));
          }

          // Asientos ocupados
          List<dynamic> occupiedList = data['occupiedSeats'] ?? [];
          Set<String> occupiedSet = occupiedList.map((e) => e.toString()).toSet();

          // Precios por fila
          Map<String, dynamic> pricesMap = data['rowPrices'] ?? {};
          Map<int, int> rowPrices = {};
          for (int i = 0; i < rowCount; i++) {
            if (pricesMap.containsKey(i.toString())) {
              rowPrices[i] = pricesMap[i.toString()];
            } else {
              // Valores por defecto
              if (i == 0) {
                rowPrices[i] = 250;
              } else if (i == 1) {
                rowPrices[i] = 200;
              } else if (i == 2) {
                rowPrices[i] = 150;
              } else {
                rowPrices[i] = 200;
              }
            }
          }

          // Calcular asientos seleccionados y subtotal
          List<String> selectedSeats = [];
          int subtotal = 0;
          for (int i = 0; i < seatStatus.length; i++) {
            for (int j = 0; j < seatStatus[i].length; j++) {
              if (seatStatus[i][j]) {
                String seatId = "${String.fromCharCode(65 + i)}${j + 1}";
                selectedSeats.add(seatId);
                subtotal += rowPrices[i] ?? 0;
              }
            }
          }
          int total = subtotal;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Escoge los asientos.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // RepaintBoundary para capturar el croquis
                  RepaintBoundary(
                    key: _repaintKey,
                    child: Container(

                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barra gris (representación de la pantalla)
                          Container(
                            height: 20,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.only(bottom: 20),
                          ),
                          // Números de columna
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 20),
                              ...List.generate(colCount, (index) {
                                return Expanded(
                                  child: Center(child: Text("${index + 1}")),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Filas de asientos
                          ...List.generate(rowCount, (row) {
                            return Row(
                              children: [
                                // Etiqueta de la fila (A, B, C, ...)
                                SizedBox(
                                  width: 20,
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + row),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                ...List.generate(colCount, (col) {
                                  String seatId = "${String.fromCharCode(65 + row)}${col + 1}";
                                  bool isOccupied = occupiedSet.contains(seatId);
                                  bool isSelected = seatStatus[row][col];
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: GestureDetector(
                                        onTap: () => toggleSeat(row, col, occupiedSet),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 1),
                                            color: isOccupied
                                                ? Colors.purple
                                                : (isSelected ? Colors.pinkAccent : Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                          const SizedBox(height: 20),

                          // Leyenda
                          Row(
                            children: [
                              Container(width: 16, height: 16, color: Colors.purple),
                              const SizedBox(width: 5),
                              const Text("Ocupado"),
                              const SizedBox(width: 15),
                              Container(width: 16, height: 16, color: Colors.grey),
                              const SizedBox(width: 5),
                              const Text("Libre"),
                              const SizedBox(width: 15),
                              Container(width: 16, height: 16, color: Colors.pinkAccent),
                              const SizedBox(width: 5),
                              const Text("Seleccionado"),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Precios por fila
                          const Text("Precios:", style: TextStyle(fontWeight: FontWeight.bold)),
                          ...List.generate(rowCount, (i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text("Fila ${String.fromCharCode(65 + i)}:"),
                                  ),
                                  Text("\$${rowPrices[i]}"),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),

                          // Asientos seleccionados y totales
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text("Asientos:")),
                              Text(selectedSeats.isEmpty ? "" : selectedSeats.join(", ")),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text("Subtotal:")),
                              Text("\$${subtotal}"),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text("Total:")),
                              Text("\$${total}"),
                            ],
                          ),
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botones
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _captureAndSharePng,
                        icon: const Icon(Icons.share, color: Colors.white, size: 18),
                        label: const Text("Compartir", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Ir a la pantalla de editar filas y columnas
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditarFilasColumnasScreen()),
                          );
                        },
                        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                        label: const Text("Editar sillas", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: selectedSeats.isEmpty
                            ? null
                            : () {
                          // Ir a la pantalla de pago
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PagoBoletosScreen(
                                nombreCliente: "",
                                apellidoCliente: "",
                                asientosSeleccionados: selectedSeats,
                                total: total,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                        label: const Text("Siguiente", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D0909),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}








