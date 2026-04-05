import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../workout/workout_screen.dart';
import '../calories/calories_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _caloriesTabEpoch = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() {
      if (_currentIndex == 1 && index != 1) {
        _caloriesTabEpoch++;
      }
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      WorkoutScreen(onOpenProfile: () => _selectTab(2)),
      CaloriesScreen(key: ValueKey<int>(_caloriesTabEpoch)),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            if (_currentIndex == 1 && index != 1) {
              _caloriesTabEpoch++;
            }
            _currentIndex = index;
          });
        },
        children: tabs,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _selectTab(index);
        },
      ),
    );
  }
}
