import 'package:flutter/material.dart';

// Definimos un enum para los 3 estados posibles de un lote
enum LoteState { libre, seleccionado, ocupado }

class AsignarLoteScreen extends StatefulWidget {
  const AsignarLoteScreen({Key? key}) : super(key: key);

  @override
  State<AsignarLoteScreen> createState() => _AsignarLoteScreenState();
}

class _AsignarLoteScreenState extends State<AsignarLoteScreen> {
  // Lista de 3 lotes, con estados iniciales (puedes cambiarlo como gustes)
  // Por ejemplo, Lote 1 y 3 libres, Lote 2 ocupado.
  List<LoteState> _lotes = [
    LoteState.libre,
    LoteState.ocupado,
    LoteState.libre,
  ];

  // Función que alterna el estado del lote entre libre y seleccionado.
  // Si está ocupado, no hace nada.
  void _toggleLote(int index) {
    setState(() {
      if (_lotes[index] == LoteState.ocupado) {
        // No cambiar nada si está ocupado
      } else if (_lotes[index] == LoteState.libre) {
        _lotes[index] = LoteState.seleccionado;
      } else if (_lotes[index] == LoteState.seleccionado) {
        _lotes[index] = LoteState.libre;
      }
    });
  }

  // Devuelve el color según el estado
  Color _getColorForLote(LoteState state) {
    switch (state) {
      case LoteState.libre:
        return Colors.grey;
      case LoteState.seleccionado:
        return Colors.pink;
      case LoteState.ocupado:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asignar lote"),
        backgroundColor: const Color(0xFF5E1A47),
      ),
      // Si deseas el drawer aquí también, puedes reutilizarlo o dejarlo fuera
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escoge el lote.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Contenedor principal (blanco) con el título "Carnaval"
            Container(
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
                  const SizedBox(height: 16),
                  // Filas de los lotes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLoteBox(0, "Lote 1"),
                      _buildLoteBox(1, "Lote 2"),
                      _buildLoteBox(2, "Lote 3"),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Leyenda de colores
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
            // Botones inferiores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Por el momento sin funcionalidad
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                  ),
                  child: const Text("Compartir"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // Por el momento sin funcionalidad
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                  ),
                  child: const Text("Editar lotes"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // Aquí puedes navegar a otra pantalla, o hacer la lógica que necesites
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
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

  // Construye cada "caja" de lote
  Widget _buildLoteBox(int index, String label) {
    return GestureDetector(
      onTap: () => _toggleLote(index),
      child: Container(
        width: 80,
        height: 150,
        color: _getColorForLote(_lotes[index]),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Construye la leyenda de colores
  Widget _buildLegendCircle(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(text),
      ],
    );
  }
}
