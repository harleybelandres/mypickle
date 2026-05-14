import 'dart:async';

import 'package:flutter/material.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF4F7F2),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 120,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDDE7D9)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/picletrack_logo.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'PickleTrack logo',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'PickleTrack',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF183A2E),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tournament brackets, registrations, and games in one place.',
                  style: TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                const LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
