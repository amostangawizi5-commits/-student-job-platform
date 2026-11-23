import 'dart:async';

import 'package:flutter/material.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _nextScreenTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _nextScreenTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/splash');
    });
  }

  @override
  void dispose() {
    _nextScreenTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF28C28),
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: .82, end: 1).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: const Text(
              'TRAINING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
