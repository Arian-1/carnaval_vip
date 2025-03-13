import 'package:flutter/material.dart';

class AsignarSillaScreen extends StatefulWidget {
  const AsignarSillaScreen({super.key});

  @override
  _AsignarSillaScreenState createState() => _AsignarSillaScreenState();
}

class _AsignarSillaScreenState extends State<AsignarSillaScreen> {
  final List<List<bool>> seatStatus = List.generate(3, (row) => List.generate(10, (col) => false));
  final List<List<bool>> occupiedSeats = [
    [false, false, true, false, false, false, false, false, false, false],
    [false, false, true, false, false, false, false, false, false, false],
    [false, false, false, false, false, false, false, false, false, false],
  ];

  final Map<int, int> rowPrices = {0: 250, 1: 200, 2: 150};
  List<String> selectedSeats = [];

  void toggleSeat(int row, int col) {
    if (!occupiedSeats[row][col]) {
      setState(() {
        seatStatus[row][col] = !seatStatus[row][col];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    selectedSeats = [];
    int subtotal = 0;
    for (int i = 0; i < seatStatus.length; i++) {
      for (int j = 0; j < seatStatus[i].length; j++) {
        if (seatStatus[i][j]) {
          selectedSeats.add("${String.fromCharCode(65 + i)}${j + 1}");
          subtotal += rowPrices[i]!;
        }
      }
    }
    
    final total = subtotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "CARNAVAL VIP",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escoge los asientos.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Screen representation
                  Container(
                    height: 20,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                  
                  // Row numbers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 20),
                      ...List.generate(10, (index) => Expanded(
                        child: Center(child: Text("${index + 1}")),
                      )),
                    ],
                  ),
                  
                  // Seats
                  ...List.generate(3, (row) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + row),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        ...List.generate(10, (col) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: GestureDetector(
                                onTap: () => toggleSeat(row, col),
                                child: CircleAvatar(
                                  backgroundColor: occupiedSeats[row][col]
                                      ? Colors.purple.shade800
                                      : (seatStatus[row][col] ? Colors.pink.shade200 : Colors.grey.shade200),
                                  radius: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                  
                  const SizedBox(height: 20),
                  
                  // Legend
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        color: Colors.purple.shade800,
                      ),
                      const SizedBox(width: 5),
                      const Text("Ocupado"),
                      const SizedBox(width: 15),
                      Container(
                        width: 16,
                        height: 16,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(width: 5),
                      const Text("Libre"),
                      const SizedBox(width: 15),
                      Container(
                        width: 16,
                        height: 16,
                        color: Colors.pink.shade200,
                      ),
                      const SizedBox(width: 5),
                      const Text("Seleccionado"),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Prices info
                  const Text("Precios:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Fila A:")),
                        Text("\$${rowPrices[0]}"),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Fila B:")),
                        Text("\$${rowPrices[1]}"),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Fila C")),
                        Text("\$${rowPrices[2]}"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Selected seats and total
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Asientos:")),
                        Text(selectedSeats.isEmpty ? "" : selectedSeats.join(", ")),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Subtotal:")),
                        Text("\$${subtotal}"),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 80, child: Text("Total:")),
                        Text("\$${total}"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Action buttons - Using Wrap to prevent overflow
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
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
                        onPressed: () {},
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
                        onPressed: () {},
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
          ],
        ),
      ),
    );
  }
}