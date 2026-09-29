import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'train_hub_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart'; 

class AppShell extends StatefulWidget {
  final String userName;
  final String userId;
  final String accessToken; // Newly added, strictly separated from userId!

  const AppShell({
    super.key, 
    required this.userName, 
    required this.userId,
    required this.accessToken,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            userName: widget.userName, 
            userId: widget.userId,
            accessToken: widget.accessToken,
            onNavigateToReports: () {
              setState(() {
                _currentIndex = 2; 
              });
            },
          ),
          const TrainHubScreen(),
          // ✅ Missing wiring added here
          ReportsScreen(
            userId: widget.userId,
            accessToken: widget.accessToken,
          ), 
          const ProfileScreen(), 
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00E5FF), 
        unselectedItemColor: Colors.grey.shade500,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 16,
        items: const [
          BottomNavigationBarItem(
            activeIcon: Icon(Icons.home_filled),
            icon: Icon(Icons.home_outlined), 
            label: 'Home'
          ),
          //   Upgraded to a holistic training icon
          BottomNavigationBarItem(
            activeIcon: Icon(Icons.directions_run_rounded),
            icon: Icon(Icons.directions_run_outlined), // Or simply 'directions_run' if outlined throws an error in your Flutter version
            label: 'Train'
          ),
          BottomNavigationBarItem(
            activeIcon: Icon(Icons.insert_chart_rounded),
            icon: Icon(Icons.insert_chart_outlined), 
            label: 'Reports'
          ),
          BottomNavigationBarItem(
            activeIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outline_rounded), 
            label: 'Profile'
          ),
        ],
      ),
    );
  }
}