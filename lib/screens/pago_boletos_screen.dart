import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asignacion_exitosa_screen.dart';

class PagoBoletosScreen extends StatefulWidget {
  final String nombreCliente;
  final String apellidoCliente;
  final List<String> asientosSeleccionados;
  final int total;

  const PagoBoletosScreen({
    Key? key,
    required this.nombreCliente,
    required this.apellidoCliente,
    required this.asientosSeleccionados,
    required this.total,
  }) : super(key: key);

  @override
  _PagoBoletosScreenState createState() => _PagoBoletosScreenState();
}

class _PagoBoletosScreenState extends State<PagoBoletosScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _abonoCtrl;

  bool _isPendiente = false; // false => pagado, true => pendiente

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreCliente);
    _apellidoCtrl = TextEditingController(text: widget.apellidoCliente);
    _abonoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  double _calcularPendiente() {
    if (!_isPendiente) return 0.0;
    final abono = double.tryParse(_abonoCtrl.text) ?? 0.0;
    final total = widget.total.toDouble();
    final restante = total - abono;
    return restante < 0 ? 0 : restante;
  }

  Future<void> _asignar() async {
    final firestore = FirebaseFirestore.instance;

    // 1) Actualizar asientos ocupados en la sala "sala1"
    await firestore.collection("salas").doc("sala1").update({
      'occupiedSeats': FieldValue.arrayUnion(widget.asientosSeleccionados),
    });

    // 2) Preparar los valores para la reserva
    //    Unificamos la estructura con "tipo": "silla"
    final double abonoVal =
    _isPendiente ? double.tryParse(_abonoCtrl.text) ?? 0.0 : widget.total.toDouble();
    final double pendienteVal = widget.total - abonoVal;

    final reservaData = {
      'tipo': 'silla', // Indica que es una reserva de sillas
      'nombre': _nombreCtrl.text,
      'apellido': _apellidoCtrl.text,
      // Guardamos los asientos como array
      'asientos': widget.asientosSeleccionados,
      'total': widget.total,
      'pagado': !_isPendiente,
      'abono': abonoVal,
      'pendiente': pendienteVal < 0 ? 0.0 : pendienteVal,
      'fecha': FieldValue.serverTimestamp(),
    };

    // 3) Guardar la información de la reserva en la colección "reservas"
    await firestore.collection("reservas").add(reservaData);
  }

  @override
  Widget build(BuildContext context) {
    final pendienteRestante = _calcularPendiente();

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Center(
            child: Container(
              width: 400, // Ancho máximo
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pago de boletos",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Nombre del cliente
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre del cliente",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingrese el nombre";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  // Apellido del cliente
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(
                      labelText: "Apellido del cliente",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingrese el apellido";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Resumen de asientos y total
                  Text("Asientos: ${widget.asientosSeleccionados.join(", ")}"),
                  Text("Total: \$${widget.total}"),
                  const SizedBox(height: 20),
                  // Selección entre Pagado / Pendiente
                  Row(
                    children: [
                      const Text("Pagado"),
                      Radio<bool>(
                        value: false,
                        groupValue: _isPendiente,
                        onChanged: (val) {
                          setState(() {
                            _isPendiente = false;
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      const Text("Pendiente"),
                      Radio<bool>(
                        value: true,
                        groupValue: _isPendiente,
                        onChanged: (val) {
                          setState(() {
                            _isPendiente = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Campo de abono (si está pendiente)
                  if (_isPendiente) ...[
                    TextFormField(
                      controller: _abonoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Abono",
                      ),
                      onChanged: (value) {
                        setState(() {}); // Actualiza el pendiente
                      },
                      validator: (value) {
                        if (_isPendiente) {
                          if (value == null || value.isEmpty) {
                            return "Ingrese el abono";
                          }
                          final abono = double.tryParse(value);
                          if (abono == null) {
                            return "Ingrese un número válido";
                          }
                          if (abono < 0) {
                            return "El abono no puede ser negativo";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Text("Pendiente: \$${pendienteRestante.toStringAsFixed(2)}"),
                  ],
                  const SizedBox(height: 20),
                  // Botón de asignar
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          await _asignar();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AsignacionExitosaScreen(),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D0909),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text("Asignar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


