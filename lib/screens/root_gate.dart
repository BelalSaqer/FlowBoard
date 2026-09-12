import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'auth_gate.dart';
import 'onboarding_screen.dart';

const _hasSeenOnboardingKey = 'hasSeenOnboarding';

/// Shows onboarding once on first launch (persisted via SharedPreferences),
/// then hands off to [AuthGate] for every launch after.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _showOnboarding = !(prefs.getBool(_hasSeenOnboardingKey) ?? false));
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_showOnboarding!) {
      return OnboardingScreen(onDone: _completeOnboarding);
    }
    return const AuthGate();
  }
}
