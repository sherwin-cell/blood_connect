import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/welcome_screen.dart';

/// First screen shown when the app launches.
///
/// Responsibilities:
/// 1. Show brand identity (logo, name, tagline) while things load.
/// 2. Give the app a moment to check auth state / cached session.
/// 3. Route the user to the right place: onboarding, login, or the
///    role-based dashboard (donor / requester / PRC admin).
///
///
/// Replace the placeholder `_decideNextRoute()` logic once Firebase Auth
/// is wired up — that's the natural home for the "am I logged in, and
/// which role am I" check.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Placeholder delay. In production this is roughly the time it takes
    // to check FirebaseAuth.instance.currentUser + fetch the user's role
    // claim, so the splash never feels like a fixed arbitrary wait.
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    _decideNextRoute();
  }

  void _decideNextRoute() {
    // TODO: replace with real auth-state check, e.g.:
    // final user = FirebaseAuth.instance.currentUser;
    // if (user == null) -> go to onboarding/login
    // else -> route by role claim (donor / requester / prc_admin)
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryRed, AppColors.deepRed],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LogoMark(),
                  const SizedBox(height: 20),
                  const Text('Blood-Connect', style: AppTextStyles.appName),
                  const SizedBox(height: 8),
                  const Text(
                    'Real-time emergency donor matching',
                    style: AppTextStyles.tagline,
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple placeholder logo mark so the splash renders correctly before
/// you drop in a real logo asset. Swap for Image.asset once you have
/// branded artwork (recommend SVG via flutter_svg).
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.water_drop_rounded,
        color: AppColors.textLight,
        size: 48,
      ),
    );
  }
}
