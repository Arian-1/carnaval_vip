import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importamos la pantalla de Login

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _pages = [
    OnboardingPage(
      imagePath: "assets/background.jpeg",
      title: "¡Bienvenido!",
      description:
      "El control total del carnaval en tus manos.\nDiseñado exclusivamente para gerentes",
      isFirstPage: true,
    ),
    OnboardingPage(
      imagePath: "assets/celular.png",
      title: "Gestión centralizada",
      description: "Asigna, organiza y controla tu evento desde un solo lugar.",
    ),
    OnboardingPage(
      imagePath: "assets/celular.png",
      title: "La herramienta definitiva para gerentes",
      description: "Toma el mando del carnaval como nunca antes.",
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // Al terminar el onboarding, vamos a la pantalla de Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
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
          // Dots indicadores
          Positioned(
            bottom: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                    (index) => _buildDot(index),
              ),
            ),
          ),
          // Botón "Siguiente" o "Iniciar sesión o crear cuenta"
          Positioned(
            bottom: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _nextPage,
              child: Text(
                _currentPage == _pages.length - 1
                    ? "Iniciar sesión o crear cuenta"
                    : "Siguiente",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
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

  OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.description,
    this.isFirstPage = false,
  });

  @override
  Widget build(BuildContext context) {
    // Si es la primera página, mostramos el fondo completo con el texto sobre la imagen
    // De lo contrario, mostramos una página morada con imagen y texto en el centro
    return isFirstPage ? _buildFirstPage() : _buildNormalPage();
  }

  Widget _buildFirstPage() {
    return Stack(
      children: [
        // Imagen de fondo
        Positioned.fill(
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
        // Contenido sobre la imagen
        Column(
          children: [
            Expanded(child: Container()), // Espaciador superior
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(fontSize: 16, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 150),
          ],
        ),
      ],
    );
  }

  Widget _buildNormalPage() {
    return Container(
      color: Color(0xFF5E1A47), // Fondo morado
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 60),
          Text(
            "¡Bienvenido!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 50),
          Image.asset(
            imagePath,
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

