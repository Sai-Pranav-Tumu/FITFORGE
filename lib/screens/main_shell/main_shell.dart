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

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const WorkoutScreen(),
      CaloriesScreen(key: ValueKey<int>(_caloriesTabEpoch)),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          PageView(
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
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == _currentIndex) return;
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
