import 'package:flutter/material.dart';

import 'pages/admin_content_page.dart';
import 'pages/live_page.dart';
import 'pages/log_page.dart';
import 'pages/setup_page.dart';
import 'theme/app_theme.dart';

class BroadcasterApp extends StatefulWidget {
  const BroadcasterApp({super.key});

  @override
  State<BroadcasterApp> createState() => _BroadcasterAppState();
}

class _BroadcasterAppState extends State<BroadcasterApp> {
  int _selectedIndex = 1;

  static const _pages = [SetupPage(), LivePage(), LogPage(), AdminContentPage()];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Taqriibussunnah Broadcaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(child: _pages[_selectedIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              selectedIcon: Icon(Icons.tune),
              label: 'Setup',
            ),
            NavigationDestination(
              icon: Icon(Icons.radio_button_checked_rounded),
              selectedIcon: Icon(Icons.podcasts_rounded),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}
