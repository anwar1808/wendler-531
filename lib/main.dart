import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/persistent_timer_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: const Wendler531App(),
    ),
  );
}

class Wendler531App extends StatelessWidget {
  const Wendler531App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wendler Log',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const MainNav(),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    ProgressScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Compact timer bar shown above the bottom nav when a rest timer
          // is active and the user is on a main tab.
          if (provider.timerActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PersistentTimerBar(provider: provider),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage('assets/skeleton_nav.png'),
              size: 24,
            ),
            activeIcon: ImageIcon(
              AssetImage('assets/skeleton_nav.png'),
              size: 24,
              color: Color(0xFFE8C547),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
