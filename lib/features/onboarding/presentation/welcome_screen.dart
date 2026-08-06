import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login_signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _slides = const [
    _OnboardingItem(
      icon: Icons.water_drop_rounded,
      title: 'Welcome to Blood-Connect',
      description:
          'Finding a compatible donor during an emergency shouldn\'t depend on luck.',
    ),
    _OnboardingItem(
      icon: Icons.search_rounded,
      title: 'Quick Donor Search',
      description:
          'Locate eligible and compatible blood donors near your area in real-time when seconds matter.',
    ),
    _OnboardingItem(
      icon: Icons.verified_user_rounded,
      title: 'Verified & Secure',
      description:
          'Identity-checked donors and recipients ensure a trustworthy and safe community for everyone.',
    ),
    _OnboardingItem(
      icon: Icons.notifications_active_rounded,
      title: 'Emergency Alerts',
      description:
          'Receive instant notifications for urgent blood requests nearby and help save lives.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    // Use push (not pushReplacement) so AuthGate stays under the stack.
    // After Google/email sign-in, popping back lets AuthGate/ProfileGate
    // route to Complete Profile and Verification.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _currentPage == _slides.length - 1 ? 0.0 : 1.0,
                  child: TextButton(
                    onPressed: _currentPage == _slides.length - 1
                        ? null
                        : _navigateToLogin,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Icon Graphic
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            color: AppColors.primaryRed,
                            size: 56,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Page Indicators (Dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primaryRed
                              : Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
