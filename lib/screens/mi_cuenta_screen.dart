// lib/screens/mi_cuenta_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  Map<String, dynamic> userData = {
    'nombre': '',
    'telefono': '',
    'email': '',
    'password': '',
  };
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            userData = {
              'nombre': data['nombre'] ?? '',
              'telefono': data['telefono'] ?? '',
              'email': user.email ?? '',
              'password': '1234', // Representación visual solamente
            };
          });
        }
      }
    } catch (e) {
      // Manejar errores
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _editField(String field, String currentValue) async {
    final TextEditingController controller = TextEditingController(text: currentValue);

    String? newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${_getFieldName(field)}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Ingrese nuevo ${_getFieldName(field)}',
          ),
          obscureText: field == 'password',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue.isNotEmpty && newValue != currentValue) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Actualizar en Firestore
          if (field != 'email' && field != 'password') {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({field: newValue});
          }

          // Actualizar email o contraseña en Authentication
          if (field == 'email') {
            await user.updateEmail(newValue);
            // También actualizar en Firestore si es necesario
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({field: newValue});
          } else if (field == 'password') {
            await user.updatePassword(newValue);
          }

          // Actualizar el estado local
          setState(() {
            userData[field] = newValue;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_getFieldName(field)} actualizado')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  String _getFieldName(String field) {
    switch (field) {
      case 'nombre':
        return 'nombre';
      case 'telefono':
        return 'teléfono';
      case 'email':
        return 'correo';
      case 'password':
        return 'contraseña';
      default:
        return field;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "CARNAVAL VIP",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF5E1A47),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi cuenta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUserInfoRow(
              Icons.person,
              userData['nombre'] ?? 'Nombre de usuario',
                  () => _editField('nombre', userData['nombre'] ?? ''),
            ),
            const Divider(),
            _buildUserInfoRow(
              Icons.phone,
              userData['telefono'] ?? '123456789',
                  () => _editField('telefono', userData['telefono'] ?? ''),
            ),
            const Divider(),
            _buildUserInfoRow(
              Icons.email,
              userData['email'] ?? 'usuario@ejemplo.com',
                  () => _editField('email', userData['email'] ?? ''),
            ),
            const Divider(),
            _buildUserInfoRow(
              Icons.lock,
              '•' * 4, // Mostrar asteriscos para la contraseña
                  () => _editField('password', ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(IconData icon, String text, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}