import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/onboarding_screen.dart';
import 'screens/config_wizard_screen.dart';   // <-- tu nuevo wizard
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnaval VIP',
      debugShowCheckedModeBanner: false,
      home: const RootDecider(),
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/config':     (_) => const ConfigWizardScreen(),
        '/home':       (_) => const HomeScreen(),
      },
    );
  }
}

class RootDecider extends StatelessWidget {
  const RootDecider({Key? key}) : super(key: key);

  Future<Widget> _decide() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Si no hay sesión, vamos a onboarding/login
        return const OnboardingScreen();
      }
      // Comprobamos si el wizard ya guardó la configuración inicial
      final configDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('config')
          .doc('setup')
          .get();

      if (configDoc.exists) {
        // Ya configurado → Home
        return const HomeScreen();
      } else {
        // Primera vez → Wizard
        return const ConfigWizardScreen();
      }
    } catch (e, st) {
      // En caso de error, fallback a onboarding
      debugPrint('Error en RootDecider._decide(): $e\n$st');
      return const OnboardingScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _decide(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        return snap.data!;
      },
    );
  }
}


