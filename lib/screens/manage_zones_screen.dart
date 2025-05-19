// lib/screens/manage_zones_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'asignar_sillas.dart';
import 'asignar_lote_screen.dart';
import 'asignar_tarima_screen.dart';
import 'editar_lotes_screen.dart';
import 'editar_filas_columnas_screen.dart';
import 'editar_tarimas_screen.dart';
import 'confirmacion_edicion_screen.dart';

class ManageZonesScreen extends StatefulWidget {
  const ManageZonesScreen({Key? key}) : super(key: key);

  @override
  State<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends State<ManageZonesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _zones = [];
  late DocumentReference _setupRef;

  // Variables temporales para la configuración de zonas
  int _rowCount = 1;
  int _colCount = 1;
  int _totalCount = 1;
  String _extraName = '';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _setupRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('config')
        .doc('setup');
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      setState(() => _loading = true);

      final setupDoc = await _setupRef.get();
      if (!setupDoc.exists) {
        // Si no existe setup, crearlo con valores iniciales
        await _setupRef.set({
          'tarimas': 0,
          'zonesLotes': 0,
          'zonaSillas': 0,
          'extras': [],
        });
      }

      final data = setupDoc.data() as Map<String, dynamic>;

      // Cargar todas las zonas
      final List<Map<String, dynamic>> zones = [];

      // Zonas de sillas
      final zonaSillas = data['zonaSillas'] as int? ?? 0;
      for (int i = 0; i < zonaSillas; i++) {
        zones.add({
          'id': 'sillas_${i+1}',
          'name': 'Sillas ${i+1}',
          'tipo': 'sillas',
          'index': i,
        });
      }

      // Zonas de lotes
      final zonesLotes = data['zonesLotes'] as int? ?? 0;
      for (int i = 0; i < zonesLotes; i++) {
        zones.add({
          'id': 'lotes_${i+1}',
          'name': 'Lotes ${i+1}',
          'tipo': 'lotes',
          'index': i,
        });
      }

      // Zonas de tarimas
      final tarimas = data['tarimas'] as int? ?? 0;
      for (int i = 0; i < tarimas; i++) {
        zones.add({
          'id': 'tarimas_${i+1}',
          'name': 'Tarimas ${i+1}',
          'tipo': 'tarimas',
          'index': i,
        });
      }

      // Extras
      final extras = List<String>.from(data['extras'] ?? []);
      for (int i = 0; i < extras.length; i++) {
        zones.add({
          'id': extras[i].toLowerCase(),
          'name': extras[i],
          'tipo': 'extras',
          'index': i,
        });
      }

      setState(() {
        _zones = zones;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addZone(String tipo) async {
    try {
      // Validaciones de cantidades
      if ((tipo == 'sillas' || tipo == 'tarimas') && _totalCount > _rowCount * _colCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El total no puede ser mayor que filas × columnas (${_rowCount * _colCount})')),
        );
        return;
      }

      if (_totalCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El total debe ser mayor a 0')),
        );
        return;
      }

      if ((tipo == 'sillas' || tipo == 'tarimas') && (_rowCount <= 0 || _colCount <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filas y columnas deben ser mayores a 0')),
        );
        return;
      }

      final setupDoc = await _setupRef.get();
      final data = setupDoc.data() as Map<String, dynamic>;

      if (tipo == 'extras') {
        // Manejar extras de manera especial
        if (_extraName.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El nombre de la zona no puede estar vacío')),
          );
          return;
        }

        final extras = List<String>.from(data['extras'] ?? []);
        extras.add(_extraName);
        await _setupRef.update({'extras': extras});

        // Crear en layout
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('layout')
            .doc(_extraName.toLowerCase())
            .set({
          'name': _extraName,
          'position': {'x': 0, 'y': 0},
          'size': {'width': 100, 'height': 80},
        });

        // Recargar zonas
        _loadZones();

        // Mostrar confirmación
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
        ).then((_) => _loadZones());

        return;
      }

      // Para zonas normales (sillas, lotes, tarimas)

      // Obtener el contador actual de este tipo de zona
      // Para zonas normales (sillas, lotes, tarimas)

      // Obtener el contador actual de este tipo de zona
      String field;
      switch (tipo) {
        case 'sillas':
          field = 'zonaSillas';
          break;
        case 'lotes':
          field = 'zonesLotes';
          break;
        case 'tarimas':
          field = 'tarimas';
          break;
        default:
          throw Exception('Tipo de zona desconocido');
      }

      final count = (data[field] as int?) ?? 0;

      // Incrementar el contador
      await _setupRef.update({field: count + 1});

      // Crear entrada en layout (para el croquis)
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final layoutRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('layout')
          .doc('${tipo}_${count+1}');

      await layoutRef.set({
        'name': '${tipo.capitalize()} ${count+1}',
        'position': {'x': 0, 'y': 0},
        'size': {'width': 100, 'height': 80},
      });

      // Actualizar también la colección de config específica por tipo
      if (tipo == 'sillas') {
        final sillasRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('config')
            .doc('sillas');

        final sillasDoc = await sillasRef.get();
        final sillasData = sillasDoc.data() as Map<String, dynamic>? ?? {};

        final counts = List<int>.from(sillasData['counts'] ?? []);
        final rows = List<int>.from(sillasData['rows'] ?? []);
        final cols = List<int>.from(sillasData['cols'] ?? []);

        // Asegurar longitud adecuada
        while (counts.length <= count) counts.add(0);
        while (rows.length <= count) rows.add(1);
        while (cols.length <= count) cols.add(1);

        // Usar valores del diálogo
        counts[count] = _totalCount;
        rows[count] = _rowCount;
        cols[count] = _colCount;

        await sillasRef.set({
          'counts': counts,
          'rows': rows,
          'cols': cols,
        }, SetOptions(merge: true));

        // No iniciamos precio para que se solicite al abrir la zona
      }
      else if (tipo == 'lotes') {
        final lotesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('config')
            .doc('lotes');

        final lotesDoc = await lotesRef.get();
        final lotesData = lotesDoc.data() as Map<String, dynamic>? ?? {};

        final counts = List<int>.from(lotesData['counts'] ?? []);

        // Asegurar longitud adecuada
        while (counts.length <= count) counts.add(1);

        // Usar valor del diálogo
        counts[count] = _totalCount;

        await lotesRef.set({
          'counts': counts,
        }, SetOptions(merge: true));

        // No iniciamos precio para que se solicite al abrir la zona
      }
      else if (tipo == 'tarimas') {
        final tarimasRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('config')
            .doc('tarimas');

        final tarimasDoc = await tarimasRef.get();
        final tarimasData = tarimasDoc.data() as Map<String, dynamic>? ?? {};

        var zones = tarimasData['zones'];
        if (zones == null) {
          zones = {};
        }
        else if (zones is List) {
          // Convertir lista a mapa
          final Map<String, dynamic> newZones = {};
          for (int i = 0; i < zones.length; i++) {
            newZones[i.toString()] = zones[i];
          }
          zones = newZones;
        }

        // Añadir nueva zona con valores del diálogo
        (zones as Map<String, dynamic>)[count.toString()] = {
          'rows': _rowCount,
          'cols': _colCount,
          'count': _totalCount,
        };

        await tarimasRef.set({
          'zones': zones,
        }, SetOptions(merge: true));

        // No iniciamos precio para que se solicite al abrir la zona
      }

      // Recargar zonas
      _loadZones();

      // Mostrar confirmación
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
        ).then((_) => _loadZones());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    try {
      final tipo = zone['tipo'] as String;
      final index = zone['index'] as int;
      final zoneNumber = (index + 1).toString(); // Convertir a string como "1", "2", etc.

      // Solicitar confirmación antes de eliminar
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar la zona ${zone['name']}?\n\nSe eliminarán todas las reservas asociadas a esta zona.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) return;

      final uid = FirebaseAuth.instance.currentUser!.uid;

      if (tipo == 'extras') {
        // Manejar extras de manera especial
        final setupDoc = await _setupRef.get();
        final data = setupDoc.data() as Map<String, dynamic>;
        final extras = List<String>.from(data['extras'] ?? []);

        if (index < extras.length) {
          extras.removeAt(index);
          await _setupRef.update({'extras': extras});

          // Eliminar del layout
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('layout')
              .doc(zone['id'])
              .delete();

          // Recargar zonas
          _loadZones();

          // Mostrar confirmación
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
          ).then((_) => _loadZones());
        }

        return;
      }

      // Para zonas normales
      String tipoReserva = tipo.substring(0, tipo.length - 1); // remover 's' final

      // 1. Buscar y eliminar todas las reservas asociadas a esta zona
      try {
        final reservasQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reservas')
            .where('tipo', isEqualTo: tipoReserva)
            .where('zona', isEqualTo: zoneNumber) // Usar zoneNumber en lugar de index
            .get();

        print('Encontradas ${reservasQuery.docs.length} reservas para eliminar');

        for (var doc in reservasQuery.docs) {
          await doc.reference.delete();
          print('Eliminada reserva ${doc.id}');
        }
      } catch (e) {
        print('Error al eliminar reservas: $e');
      }

      // 2. Eliminar la entrada en layout
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('layout')
          .doc(zone['id'])
          .delete();

      // 3. Actualizar el contador en setup
      final setupDoc = await _setupRef.get();
      final data = setupDoc.data() as Map<String, dynamic>;

      String field;
      switch (tipo) {
        case 'sillas':
          field = 'zonaSillas';
          break;
        case 'lotes':
          field = 'zonesLotes';
          break;
        case 'tarimas':
          field = 'tarimas';
          break;
        default:
          throw Exception('Tipo de zona desconocido');
      }

      final count = (data[field] as int?) ?? 0;
      if (count > 0) {
        await _setupRef.update({field: count - 1});
      }

      // 4. También eliminar los datos de configuración específicos y precios de la zona eliminada
      try {
        if (tipo == 'sillas') {
          // Eliminar precios
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('config')
              .doc('prices')
              .collection('sillas')
              .doc('zona_${zoneNumber}')
              .delete();
        }
        else if (tipo == 'lotes') {
          // Eliminar precios
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('config')
              .doc('prices')
              .collection('lotes')
              .doc('zona_${zoneNumber}')
              .delete();
        }
        else if (tipo == 'tarimas') {
          // Eliminar precios
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('config')
              .doc('prices')
              .collection('tarimas')
              .doc('zona_${zoneNumber}')
              .delete();
        }
      } catch (e) {
        print('Error al eliminar configuración de precios: $e');
      }

      // 5. Recargar zonas
      _loadZones();

      // Mostrar confirmación
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
        ).then((_) => _loadZones());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddZoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir nueva zona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_seat, color: Colors.purple),
              title: const Text('Zona de Sillas'),
              onTap: () {
                Navigator.pop(context);
                _showSillasConfigDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view, color: Colors.redAccent),
              title: const Text('Zona de Lotes'),
              onTap: () {
                Navigator.pop(context);
                _showLotesConfigDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.business, color: Colors.pink),
              title: const Text('Zona de Tarimas'),
              onTap: () {
                Navigator.pop(context);
                _showTarimasConfigDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box, color: Colors.green),
              title: const Text('Zona Extra'),
              onTap: () {
                Navigator.pop(context);
                _showExtrasConfigDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showSillasConfigDialog() {
    _rowCount = 1;
    _colCount = 1;
    _totalCount = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Zona de Sillas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Número de filas',
                  hintText: 'Ej: 3',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _rowCount = int.tryParse(v) ?? 1,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Número de columnas',
                  hintText: 'Ej: 5',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _colCount = int.tryParse(v) ?? 1,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Total de asientos',
                  hintText: 'Ej: 15',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _totalCount = int.tryParse(v) ?? 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validaciones
              if (_totalCount <= 0 || _rowCount <= 0 || _colCount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todos los valores deben ser mayores a 0')),
                );
                return;
              }

              if (_totalCount > _rowCount * _colCount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El número de sillas no puede exceder filas × columnas')),
                );
                return;
              }

              // Verificar espacios vacíos
              int totalSlots = _rowCount * _colCount;
              int emptySlots = totalSlots - _totalCount;
              double utilizationRate = _totalCount / totalSlots;

              if (utilizationRate < 0.5) {
                // Mostrar advertencia pero sin cerrar el diálogo actual
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Configuración ineficiente'),
                    content: Text(
                        'Tu configuración tendrá $emptySlots espacios vacíos de $totalSlots (${(emptySlots / totalSlots * 100).toStringAsFixed(1)}% desperdiciado).\n\n'
                            '¿Estás seguro de que quieres continuar?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx), // Volver al diálogo anterior
                        child: const Text('Revisar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Cerrar diálogo de advertencia
                          Navigator.pop(context); // Cerrar diálogo de configuración
                          _addZone('sillas'); // Proceder con la creación
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A0F4D),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                );
              } else {
                // Proceder normalmente si no hay problema de espacios vacíos
                Navigator.pop(context);
                _addZone('sillas');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showTarimasConfigDialog() {
    _rowCount = 1;
    _colCount = 1;
    _totalCount = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Zona de Tarimas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Número de filas',
                  hintText: 'Ej: 2',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _rowCount = int.tryParse(v) ?? 1,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Número de columnas',
                  hintText: 'Ej: 3',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _colCount = int.tryParse(v) ?? 1,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Total de tarimas',
                  hintText: 'Ej: 6',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _totalCount = int.tryParse(v) ?? 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validaciones
              if (_totalCount <= 0 || _rowCount <= 0 || _colCount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todos los valores deben ser mayores a 0')),
                );
                return;
              }

              if (_totalCount > _rowCount * _colCount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El número de tarimas no puede exceder filas × columnas')),
                );
                return;
              }

              // Verificar espacios vacíos
              int totalSlots = _rowCount * _colCount;
              int emptySlots = totalSlots - _totalCount;
              double utilizationRate = _totalCount / totalSlots;

              if (utilizationRate < 0.5) {
                // Mostrar advertencia pero sin cerrar el diálogo actual
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Configuración ineficiente'),
                    content: Text(
                        'Tu configuración tendrá $emptySlots espacios vacíos de $totalSlots (${(emptySlots / totalSlots * 100).toStringAsFixed(1)}% desperdiciado).\n\n'
                            '¿Estás seguro de que quieres continuar?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx), // Volver al diálogo anterior
                        child: const Text('Revisar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Cerrar diálogo de advertencia
                          Navigator.pop(context); // Cerrar diálogo de configuración
                          _addZone('tarimas'); // Proceder con la creación
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A0F4D),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                );
              } else {
                // Proceder normalmente si no hay problema de espacios vacíos
                Navigator.pop(context);
                _addZone('tarimas');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showLotesConfigDialog() {
    _totalCount = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Zona de Lotes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: '1'),
                decoration: const InputDecoration(
                  labelText: 'Número de lotes',
                  hintText: 'Ej: 10',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _totalCount = int.tryParse(v) ?? 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validación simple para lotes: solo verificar que sea mayor a 0
              if (_totalCount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El número de lotes debe ser mayor a 0')),
                );
                return;
              }

              Navigator.pop(context);
              _addZone('lotes');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showExtrasConfigDialog() {
    _extraName = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Zona Extra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(),
                decoration: const InputDecoration(
                  labelText: 'Nombre de la zona',
                  hintText: 'Ej: Baños, Escenario, Bar...',
                ),
                onChanged: (v) => _extraName = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addZone('extras');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _navigateToZone(Map<String, dynamic> zone) {
    final tipo = zone['tipo'] as String;
    if (tipo == 'extras') {
      // Las zonas extras no tienen pantallas dedicadas
      return;
    }

    final index = zone['index'] as int;

    if (tipo == 'sillas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarSillaScreen(zoneIndex: index),
        ),
      );
    } else if (tipo == 'lotes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarLoteScreen(zoneIndex: index),
        ),
      );
    } else if (tipo == 'tarimas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AsignarTarimaScreen(zoneIndex: index),
        ),
      );
    }
  }

  void _editZone(Map<String, dynamic> zone) {
    final tipo = zone['tipo'] as String;
    if (tipo == 'extras') {
      // Mostrar diálogo para editar nombre
      _showEditExtraNameDialog(zone);
      return;
    }

    final index = zone['index'] as int;

    if (tipo == 'sillas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditarFilasColumnasScreen(zoneIndex: index),
        ),
      ).then((_) => _loadZones());
    } else if (tipo == 'lotes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditarLotesScreen(zoneIndex: index),
        ),
      ).then((_) => _loadZones());
    } else if (tipo == 'tarimas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditarTarimasScreen(zoneIndex: index),
        ),
      ).then((_) => _loadZones());
    }
  }

  void _showEditExtraNameDialog(Map<String, dynamic> zone) {
    final controller = TextEditingController(text: zone['name']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre de la zona',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == zone['name']) {
                Navigator.pop(context);
                return;
              }

              // Actualizar nombre
              final uid = FirebaseAuth.instance.currentUser!.uid;

              // 1. Actualizar en lista extras
              final setupDoc = await _setupRef.get();
              final data = setupDoc.data() as Map<String, dynamic>;
              final extras = List<String>.from(data['extras'] ?? []);

              final index = zone['index'] as int;
              if (index < extras.length) {
                // Borrar el viejo
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('layout')
                    .doc(zone['id'])
                    .delete();

                // Actualizar en la lista
                extras[index] = newName;
                await _setupRef.update({'extras': extras});

                // Crear nuevo con mismo ID pero nombre actualizado
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('layout')
                    .doc(newName.toLowerCase())
                    .set({
                  'name': newName,
                  'position': {'x': 0, 'y': 0},
                  'size': {'width': 100, 'height': 80},
                });

                // Recargar zonas
                _loadZones();
              }

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Zonas', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddZoneDialog,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF5A0F4D),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
          ? const Center(child: Text('No hay zonas configuradas'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zonas Disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _zones.length,
                itemBuilder: (context, index) {
                  final zone = _zones[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: _getTipoIcon(zone['tipo']),
                      title: Text(zone['name']),
                      subtitle: Text(_getTipoLabel(zone['tipo'])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editZone(zone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteZone(zone),
                          ),
                        ],
                      ),
                      onTap: () => _navigateToZone(zone),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'sillas':
        return const Icon(Icons.event_seat, color: Colors.purple);
      case 'lotes':
        return const Icon(Icons.grid_view, color: Colors.redAccent);
      case 'tarimas':
        return const Icon(Icons.business, color: Colors.pink);
      case 'extras':
        return const Icon(Icons.add_box, color: Colors.green);
      default:
        return const Icon(Icons.question_mark);
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'sillas':
        return 'Zona de Sillas';
      case 'lotes':
        return 'Zona de Lotes';
      case 'tarimas':
        return 'Zona de Tarimas';
      case 'extras':
        return 'Zona Extra';
      default:
        return 'Tipo desconocido';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}