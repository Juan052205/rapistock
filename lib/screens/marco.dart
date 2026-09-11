import 'package:flutter/material.dart';
import '../theme.dart';
import 'ajustes.dart';
import 'bodega.dart';
import 'historial.dart';
import 'movimiento.dart';
import 'tablero.dart';

class MarcoPantalla extends StatefulWidget {
  const MarcoPantalla({super.key});

  @override
  State<MarcoPantalla> createState() => _MarcoPantallaState();
}

class _MarcoPantallaState extends State<MarcoPantalla> {
  int indice = 1; // Mover es el corazón del mostrador

  static const _pantallas = <Widget>[
    BodegaPantalla(),
    MovimientoPantalla(),
    HistorialPantalla(),
    TableroPantalla(),
    AjustesPantalla(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: indice, children: _pantallas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indice,
        onTap: (i) => setState(() => indice = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: R.forest,
        unselectedItemColor: R.muted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Bodega',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Mover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Tablero',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}