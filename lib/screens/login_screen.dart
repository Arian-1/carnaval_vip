// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'onboarding_screen.dart';
import 'config_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage      = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final pass  = _passwordController.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Ingresa correo y contraseña');
      return;
    }

    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;

      // Comprobamos si existe la configuración inicial (config/setup)
      final configSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('config')
          .doc('setup')
          .get();

      if (configSnap.exists) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/config');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Error de autenticación');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5E1A47),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Correo electrónico",
                labelStyle: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Contraseña",
                labelStyle: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),

            // Botón Iniciar sesión
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              onPressed: _iniciarSesion,
              child: const Text("Iniciar sesión"),
            ),
            const SizedBox(height: 10),

            // Olvidé mi contraseña
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                );
              },
              child: const Text(
                "¿Olvidaste tu contraseña?",
                style: TextStyle(color: Colors.white),
              ),
            ),

            // Crear cuenta
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                minimumSize: const Size.fromHeight(45),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text(
                "Crear cuenta",
                style: TextStyle(color: Colors.white),
              ),
            ),

            // Mensaje de error
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}





