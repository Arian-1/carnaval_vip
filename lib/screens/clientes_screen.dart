// lib/screens/clientes_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({Key? key}) : super(key: key);

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _searchCtrl = TextEditingController();
  late final CollectionReference _reservasCol;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _reservasCol = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reservas');
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await _reservasCol.orderBy('fecha', descending: true).get();
    final list = snap.docs.map((d) {
      final m = d.data()! as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
    setState(() {
      _all = list;
      _filtered = list;
    });
  }

  void _filter(String q) {
    q = q.toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        final fn = '${r['nombre']} ${r['apellido']}'.toLowerCase();
        return fn.contains(q);
      }).toList();
    });
  }

  Future<void> _delete(String id) async {
    await _reservasCol.doc(id).delete();
    await _fetch();
  }

  Future<void> _showEditDialog(Map<String, dynamic> r) async {
    final id           = r['id'] as String;
    final nombreCtrl   = TextEditingController(text: r['nombre']);
    final apellidoCtrl = TextEditingController(text: r['apellido']);
    final abonoCtrl    = TextEditingController(text: '${r['abono']}');
    final tipo         = r['tipo'] as String;
    final itemCtrl     = TextEditingController(
      text: tipo == 'silla'
          ? (r['asientos'] as List).join(', ')
          : (r['item'] ?? ''),
    );
    // mantenemos el total original, pero no lo editamos
    final originalTotal = (r['total'] as num).toDouble();
    DateTime fecha = (r['fecha'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Editar reserva'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextFormField(
                  controller: apellidoCtrl,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                ),
                TextFormField(
                  controller: itemCtrl,
                  decoration: InputDecoration(
                    labelText: tipo == 'silla'
                        ? 'Asientos (A1,A2,...)'
                        : 'Lote/Item',
                  ),
                ),
                // campo 'Total' mostrado pero no editable
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Text('Total: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${originalTotal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                TextFormField(
                  controller: abonoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Abono'),
                  onChanged: (_) => setSt(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Fecha:'),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy').format(fecha)),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setSt(() => fecha = d);
                      },
                    ),
                  ],
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
                final newNombre   = nombreCtrl.text.trim();
                final newApellido = apellidoCtrl.text.trim();
                final newAbono    = double.tryParse(abonoCtrl.text) ?? 0.0;
                final newPend     = (originalTotal - newAbono)
                    .clamp(0.0, double.infinity);
                final asientosList = tipo == 'silla'
                    ? itemCtrl.text.split(',').map((s)=>s.trim()).toList()
                    : null;
                final itemValue   = tipo != 'silla' ? itemCtrl.text.trim() : null;

                await _reservasCol.doc(id).update({
                  'nombre': newNombre,
                  'apellido': newApellido,
                  'abono': newAbono,
                  'pendiente': newPend,
                  'pagado': newPend == 0.0,
                  'fecha': Timestamp.fromDate(DateTime(
                      fecha.year, fecha.month, fecha.day,
                      fecha.hour, fecha.minute)),
                  if (asientosList != null) 'asientos': asientosList,
                  if (itemValue   != null) 'item': itemValue,
                });

                Navigator.pop(ctx);
                await _fetch();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    final headers = ['Zona','Nombre','Tipo','Items','Abono','Total','Pagado','Pendiente'];
    final data = _all.map((r) {
      final zoneIdx = (r['zona'] is int)
          ? r['zona'] as int
          : int.tryParse(r['zona'].toString()) ?? 0;
      final zonaStr = 'Zona ${zoneIdx+1}';
      final nombre = '${r['nombre']} ${r['apellido']}';
      final tipo   = r['tipo'] as String;
      final items  = tipo == 'silla'
          ? (r['asientos'] as List).join(', ')
          : (r['item'] ?? '');
      final abono  = (r['abono'] as num).toDouble();
      final total  = (r['total'] as num).toDouble();
      final pag    = (r['pagado'] as bool) ? '✓' : '';
      final pend   = (r['pendiente'] as num).toDouble();
      return [
        zonaStr,
        nombre,
        tipo,
        items,
        '\$${abono.toStringAsFixed(2)}',
        '\$${total.toStringAsFixed(2)}',
        pag,
        '\$${pend.toStringAsFixed(2)}',
      ];
    }).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0,
            child: pw.Text('Carnaval VIP', style: pw.TextStyle(fontSize: 24))),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generado el ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ),
      ],
    ));

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'clientes.pdf');
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _filter,
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No hay resultados'))
                  : ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final r = _filtered[i];
                  final zoneIdx = (r['zona'] is int)
                      ? r['zona'] as int
                      : int.tryParse(r['zona'].toString()) ?? 0;
                  final nombre = '${r['nombre']} ${r['apellido']}';
                  final tipo   = r['tipo'] as String;
                  final items  = tipo == 'silla'
                      ? (r['asientos'] as List).join(', ')
                      : (r['item'] ?? '');
                  final estatus= (r['pagado'] as bool) ? 'Pagado' : 'Pendiente';

                  return ListTile(
                    title: Text(nombre),
                    subtitle: Text('Zona ${zoneIdx+1} • $tipo → $items'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(estatus),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditDialog(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r['id'] as String),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.download),
              label: const Text('Descargar tabla de clientes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E1A47),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
