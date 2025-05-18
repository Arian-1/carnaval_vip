// lib/screens/proveedores_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({Key? key}) : super(key: key);

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final _searchCtrl = TextEditingController();
  late final CollectionReference _colProv;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _colProv = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('proveedores');
    _load();
  }

  Future<void> _load() async {
    final snap = await _colProv.orderBy('fecha', descending: true).get();
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
        final name = (r['nombre'] ?? '').toString().toLowerCase();
        final tipo = (r['tipo'] ?? '').toString().toLowerCase();
        return name.contains(q) || tipo.contains(q);
      }).toList();
    });
  }

  Future<void> _delete(String id) async {
    await _colProv.doc(id).delete();
    await _load();
  }

  Future<void> _showEditDialog(Map<String, dynamic> r) async {
    final id        = r['id'] as String;
    final nombreCtr = TextEditingController(text: r['nombre']);
    final tipoCtr   = TextEditingController(text: r['tipo']);
    final totalCtr  = TextEditingController(text: '${r['total']}');
    final pagoCtr   = TextEditingController(text: r['tipoPago'] ?? '');
    bool pagado     = (r['pagado'] ?? false) as bool;
    DateTime fecha  = (r['fecha'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Detalles Proveedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtr,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                ),
                TextFormField(
                  controller: tipoCtr,
                  decoration: const InputDecoration(labelText: 'Tipo de servicio'),
                ),
                TextFormField(
                  controller: totalCtr,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total (\$)'),
                ),
                TextFormField(
                  controller: pagoCtr,
                  decoration: const InputDecoration(labelText: 'Tipo de pago'),
                ),
                Row(
                  children: [
                    const Text('Pagado'),
                    Switch(
                      value: pagado,
                      onChanged: (v) => setSt(() => pagado = v),
                    ),
                  ],
                ),
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
                final upd = {
                  'nombre': nombreCtr.text.trim(),
                  'tipo': tipoCtr.text.trim(),
                  'total': double.tryParse(totalCtr.text) ?? 0,
                  'tipoPago': pagoCtr.text.trim(),
                  'pagado': pagado,
                  'fecha': Timestamp.fromDate(DateTime(
                    fecha.year, fecha.month, fecha.day,
                    fecha.hour, fecha.minute,
                  )),
                };
                await _colProv.doc(id).update(upd);
                Navigator.pop(ctx);
                await _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proveedores', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // búsqueda
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
            // encabezados
            Row(children: const [
              Expanded(flex: 3, child: Text('Proveedor', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Estatus', style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 40),
            ]),
            const Divider(),
            // lista
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No hay resultados'))
                  : ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (_, i) {
                  final r     = _filtered[i];
                  final name  = r['nombre'] ?? '';
                  final tipo  = r['tipo'] ?? '';
                  final est   = (r['pagado'] ?? false) ? 'Pagado' : 'Pendiente';
                  return Row(
                    children: [
                      Expanded(flex: 3, child: Text(name)),
                      Expanded(flex: 3, child: Text(tipo)),
                      Expanded(flex: 2, child: Text(est)),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showEditDialog(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(r['id'] as String),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // botón agregar nuevo
            FloatingActionButton(
              onPressed: () async {
                // creamos uno vacío y abrimos diálogo
                final doc = await _colProv.add({
                  'nombre': '',
                  'tipo': '',
                  'total': 0,
                  'tipoPago': '',
                  'pagado': false,
                  'fecha': FieldValue.serverTimestamp(),
                });
                final newData = (await doc.get()).data()! as Map<String, dynamic>;
                newData['id'] = doc.id;
                _showEditDialog(newData);
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
