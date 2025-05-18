// lib/screens/ventas_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({Key? key}) : super(key: key);

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  bool _loading = true;

  // Sillas
  int _sillasTotales = 0, _sillasPagadas = 0, _sillasPendientes = 0;
  double _ventasSillas = 0, _abonosSillas = 0, _pendientesSillas = 0;

  // Lotes
  int _lotesTotales = 0, _lotesPagados = 0, _lotesPendientes = 0;
  double _ventasLotes = 0, _abonosLotes = 0, _pendientesLotes = 0;

  // Proveedores
  double _gastoProveedores = 0;

  // Ganancias
  double _gananciaBruta = 0, _gananciaNeta = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // 1) Reservas
    final reservasSnap = await userRef
        .collection('reservas')
        .orderBy('fecha', descending: true)
        .get();
    for (var doc in reservasSnap.docs) {
      final r = doc.data();
      final tipo = r['tipo'] as String? ?? '';
      final pagado = r['pagado'] as bool? ?? false;
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      final abono = (r['abono'] as num?)?.toDouble() ?? 0;
      final pendiente = (r['pendiente'] as num?)?.toDouble() ?? 0;

      if (tipo == 'silla') {
        _sillasTotales++;
        _ventasSillas += total;
        _abonosSillas += abono;
        _pendientesSillas += pendiente;
        if (pagado) _sillasPagadas++;
        else _sillasPendientes++;
      } else if (tipo == 'lote') {
        _lotesTotales++;
        _ventasLotes += total;
        _abonosLotes += abono;
        _pendientesLotes += pendiente;
        if (pagado) _lotesPagados++;
        else _lotesPendientes++;
      }
    }

    // 2) Proveedores
    final provSnap = await userRef.collection('proveedores').get();
    for (var doc in provSnap.docs) {
      final p = (doc.data()['monto'] as num?)?.toDouble() ?? 0;
      _gastoProveedores += p;
    }

    // 3) Ganancias
    _gananciaBruta = (_abonosSillas + _abonosLotes) - _gastoProveedores;
    _gananciaNeta = _gananciaBruta - (_pendientesSillas + _pendientesLotes);

    setState(() => _loading = false);
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Resumen de Ventas - Carnaval VIP',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Text('🪑 SILLAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Total vendidas: $_sillasTotales'),
          pw.Bullet(text: 'Pagadas: $_sillasPagadas'),
          pw.Bullet(text: 'Pendientes: $_sillasPendientes'),
          pw.Bullet(text: 'Ventas (total): \$${_ventasSillas.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Abonos recibidos: \$${_abonosSillas.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Pendientes total: \$${_pendientesSillas.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),

          pw.Text('📦 LOTES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Total vendidas: $_lotesTotales'),
          pw.Bullet(text: 'Pagadas: $_lotesPagados'),
          pw.Bullet(text: 'Pendientes: $_lotesPendientes'),
          pw.Bullet(text: 'Ventas (total): \$${_ventasLotes.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Abonos recibidos: \$${_abonosLotes.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Pendientes total: \$${_pendientesLotes.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),

          pw.Text('💼 PROVEEDORES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Gasto total: \$${_gastoProveedores.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),

          pw.Text('💰 GANANCIAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Bruta: \$${_gananciaBruta.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Neta: \$${_gananciaNeta.toStringAsFixed(2)}'),
          pw.SizedBox(height: 24),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'ventas_resumen.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSection(
              icon: Icons.event_seat,
              title: 'Sillas',
              children: [
                'Total vendidas: $_sillasTotales',
                'Pagadas: $_sillasPagadas',
                'Pendientes: $_sillasPendientes',
                'Ventas (total): \$${_ventasSillas.toStringAsFixed(2)}',
                'Abonos recibidos: \$${_abonosSillas.toStringAsFixed(2)}',
                'Pendientes total: \$${_pendientesSillas.toStringAsFixed(2)}',
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.shopping_bag,
              title: 'Lotes',
              children: [
                'Total vendidas: $_lotesTotales',
                'Pagadas: $_lotesPagados',
                'Pendientes: $_lotesPendientes',
                'Ventas (total): \$${_ventasLotes.toStringAsFixed(2)}',
                'Abonos recibidos: \$${_abonosLotes.toStringAsFixed(2)}',
                'Pendientes total: \$${_pendientesLotes.toStringAsFixed(2)}',
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.store,
              title: 'Proveedores',
              children: [
                'Gasto total: \$${_gastoProveedores.toStringAsFixed(2)}',
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.attach_money,
              title: 'Ganancias',
              children: [
                'Bruta: \$${_gananciaBruta.toStringAsFixed(2)}',
                'Neta: \$${_gananciaNeta.toStringAsFixed(2)}',
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.download),
              label: const Text('Descargar resumen PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D0909),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF5A0F4D)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            for (var line in children)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}
