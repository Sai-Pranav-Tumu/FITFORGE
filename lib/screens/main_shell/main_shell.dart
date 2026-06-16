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
  late final PageController _pageController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // Built once and kept alive so swiping never rebuilds a heavy tab mid-drag
    // (that rebuild was the source of the mid-swipe stutter).
    _pages = <Widget>[
      _KeepAlivePage(child: WorkoutScreen(onOpenProfile: () => _selectTab(2))),
      const _KeepAlivePage(child: CaloriesScreen()),
      const _KeepAlivePage(child: ProfileScreen()),
    ];
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
    // Update the nav highlight immediately for a responsive tap.
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        // Default PageScrollPhysics snaps exactly one page per swipe. (A custom
        // underdamped spring here caused a light flick to overshoot past the
        // middle tab.) Smoothness comes from keep-alive + neighbor pre-warming.
        physics: const PageScrollPhysics(),
        // Pre-build the adjacent tab so it's ready before the swipe starts.
        allowImplicitScrolling: true,
        onPageChanged: (index) {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
          }
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

/// Keeps a tab's element tree alive while it is off-screen so returning to it
/// (or swiping past it) is instant instead of triggering a full rebuild.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
