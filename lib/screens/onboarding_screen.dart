// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importamos la pantalla de Login

class OnboardingScreen extends StatefulWidget {
  // <-- aquí agregas el constructor const
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _pages = [
    const OnboardingPage(
      imagePath: "assets/background.jpeg",
      title: "¡Bienvenido!",
      description:
      "El control total del carnaval en tus manos.\nDiseñado exclusivamente para gerentes",
      isFirstPage: true,
    ),
    const OnboardingPage(
      imagePath: "assets/celular.png",
      title: "Gestión centralizada",
      description: "Asigna, organiza y controla tu evento desde un solo lugar.",
    ),
    const OnboardingPage(
      imagePath: "assets/celular.png",
      title: "La herramienta definitiva para gerentes",
      description: "Toma el mando del carnaval como nunca antes.",
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: _pages,
          ),
          // indicadores
          Positioned(
            bottom: 100,
            child: Row(
              children: List.generate(
                _pages.length,
                    (index) => _buildDot(index),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _nextPage,
              child: Text(
                _currentPage == _pages.length - 1
                    ? "Iniciar sesión o crear cuenta"
                    : "Siguiente",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: _currentPage == index ? 12 : 8,
      height: _currentPage == index ? 12 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final bool isFirstPage;

  // y aquí agregas const también
  const OnboardingPage({
    Key? key,
    required this.imagePath,
    required this.title,
    required this.description,
    this.isFirstPage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isFirstPage ? _buildFirstPage() : _buildNormalPage();
  }

  Widget _buildFirstPage() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
        Column(
          children: [
            const Expanded(child: SizedBox()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(description,
                      style:
                      const TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 150),
          ],
        ),
      ],
    );
  }

  Widget _buildNormalPage() {
    return Container(
      color: const Color(0xFF5E1A47),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text("¡Bienvenido!",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 50),
          Image.asset(imagePath, width: 250, height: 250, fit: BoxFit.contain),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(description,
                    style:
                    const TextStyle(fontSize: 16, color: Colors.white),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
