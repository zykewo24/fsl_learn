import 'package:flutter/material.dart';

import '../../ai_practice/presentation/ai_dashboard_screen.dart';
import '../../lessons/presentation/lessons_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigateTo: _selectTab),
      LessonsScreen(),
      AiDashboardScreen(onNavigateTo: _selectTab),
      ProgressScreen(),
      ProfileScreen(),
    ];
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<String> _titles = const [
    'Home',
    'Lessons',
    'Practice',
    'Progress',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Lessons',
          ),
          NavigationDestination(
            icon: Icon(Icons.front_hand_outlined),
            selectedIcon: Icon(Icons.front_hand),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}