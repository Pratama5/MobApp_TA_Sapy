import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final String currentRoute;

  const BottomNavBar({super.key, required this.currentRoute});

  Color getIconColor(String route) {
    return currentRoute == route ? const Color(0xFFD1512D) : Colors.white70;
  }

  TextStyle getLabelStyle(String route) {
    return TextStyle(
      color: getIconColor(route),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF411530),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // HOME
          GestureDetector(
            onTap: () {
              if (currentRoute != '/') {
                Navigator.pushNamed(context, '/');
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home, size: 28, color: getIconColor('/')),
                const SizedBox(height: 4),
                Text("Home", style: getLabelStyle('/')),
              ],
            ),
          ),

          // LIBRARY
          GestureDetector(
            onTap: () {
              if (currentRoute != '/library') {
                Navigator.pushNamed(context, '/library');
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book,
                    size: 28, color: getIconColor('/library')),
                const SizedBox(height: 4),
                Text("Library", style: getLabelStyle('/library')),
              ],
            ),
          ),

          // ATTACK
          GestureDetector(
            onTap: () {
              if (currentRoute != '/attack') {
                Navigator.pushNamed(context, '/attack');
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.whatshot, size: 28, color: getIconColor('/attack')),
                const SizedBox(height: 4),
                Text("Attack", style: getLabelStyle('/attack')),
              ],
            ),
          ),

          // HISTORY
          GestureDetector(
            onTap: () {
              if (currentRoute != '/history') {
                Navigator.pushNamed(context, '/history');
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 28, color: getIconColor('/history')),
                const SizedBox(height: 4),
                Text("History", style: getLabelStyle('/history')),
              ],
            ),
          ),

          // PROFILE
          GestureDetector(
            onTap: () {
              if (currentRoute != '/profile') {
                Navigator.pushNamed(context, '/profile');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You are already on Profile screen'),
                  ),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 28, color: getIconColor('/profile')),
                const SizedBox(height: 4),
                Text("Profile", style: getLabelStyle('/profile')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
