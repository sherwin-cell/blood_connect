import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/firestore_service.dart';
import '../data/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  int _currentStep = 0;

  // Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 1 Options
  String? _selectedSuffix;
  bool _hasNoMiddleName = false;
  final List<String> _suffixOptions = ['Jr.', 'Sr.', 'III', 'IV', 'V'];

  // Loading States
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _returnToAuthGate() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // EMAIL + PASSWORD REGISTRATION
  // ============================================================

  Future<void> _onRegisterPressed() async {
    if (_isSubmitting || _isGoogleLoading) return;

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final firstName = _firstNameController.text.trim();
      final middleName = _hasNoMiddleName
          ? ''
          : _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final suffix = _selectedSuffix ?? '';

      final List<String> nameParts = [firstName];

      if (middleName.isNotEmpty) {
        nameParts.add(middleName);
      }

      nameParts.add(lastName);

      if (suffix.isNotEmpty) {
        nameParts.add(suffix);
      }

      final fullName = nameParts.join(' ');

      // Create Firebase email/password account
      final userCredential = await _authService.register(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Unable to create your account.',
        );
      }

      // Update Firebase display name
      await user.updateDisplayName(fullName);

      // Create Blood-Connect Firestore profile (incomplete until Complete Profile)
      await _firestoreService.createUserProfile(
        uid: user.uid,
        fullname: fullName,
        email: email,
      );

      // Send email verification — AuthGate shows EmailVerificationScreen next
      await _authService.sendEmailVerification();

      // Return to AuthGate root (clears Login/Register stack)
      _returnToAuthGate();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showSnackBar(AuthService.getErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ============================================================
  // GOOGLE REGISTRATION
  // ============================================================

  Future<void> _onGoogleSignInPressed() async {
    if (_isSubmitting || _isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      // Same Google → Firebase Auth flow as Login (Firebase creates Auth user
      // on first use). AuthService ensures a Firestore profile stub exists.
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential == null || userCredential.user == null) {
        if (!mounted) return;
        _showSnackBar('Google Sign-In was cancelled.');
        return;
      }

      // Return to AuthGate — ProfileGate checks profile completeness
      _returnToAuthGate();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showSnackBar(AuthService.getErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Google registration failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? null : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 24),

              // Header Logo
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_rounded,
                    color: AppColors.primaryRed,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Blood',
                          style: TextStyle(color: AppColors.primaryRed),
                        ),
                        TextSpan(
                          text: 'Connect',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                "Let's Get Started!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              if (_currentStep == 0) _buildStep1(),
              if (_currentStep == 1) _buildStep2(),
              if (_currentStep == 2) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryRed : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // STEP 1: Personal Details & Email
  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: _inputDecoration('First Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedSuffix,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: _inputDecoration('Suffix'),
                  items: _suffixOptions.map((suffix) {
                    return DropdownMenuItem(value: suffix, child: Text(suffix));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSuffix = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _middleNameController,
            enabled: !_hasNoMiddleName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: _inputDecoration('Middle Name'),
            validator: (value) {
              if (!_hasNoMiddleName &&
                  (value == null || value.trim().isEmpty)) {
                return 'Enter middle name or check the box below';
              }
              return null;
            },
          ),

          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _hasNoMiddleName,
                  activeColor: AppColors.primaryRed,
                  onChanged: (val) {
                    setState(() {
                      _hasNoMiddleName = val ?? false;

                      if (_hasNoMiddleName) {
                        _middleNameController.clear();
                      }
                    });
                  },
                ),
                Text(
                  'I have no middle name',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          TextFormField(
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: _inputDecoration('Last Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Last name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 10),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: _inputDecoration('Email Address'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email address is required';
              }

              if (!_emailRegex.hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
                children: const [
                  TextSpan(text: 'By tapping '),
                  TextSpan(
                    text: 'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(text: ', you agree with the '),
                  TextSpan(
                    text: 'Terms and Conditions',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Notice',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isGoogleLoading ? null : _nextStep,
              style: _primaryButtonStyle(),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Google Sign-In Button
          _buildGoogleSignInButton(),

          const SizedBox(height: 16),

          _buildLoginLink(),
        ],
      ),
    );
  }

  // STEP 2: Password Creation
  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Password must be at least 6 characters long.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: _inputDecoration('Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextStep(),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: _inputDecoration('Confirm Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: _primaryButtonStyle(),
              child: const Text(
                'Next Step',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: Review & Submit
  Widget _buildStep3() {
    final firstName = _firstNameController.text.trim();
    final middleName = _hasNoMiddleName
        ? ''
        : _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final suffix = _selectedSuffix ?? '';

    final nameParts = [
      firstName,
      if (middleName.isNotEmpty) middleName,
      lastName,
      if (suffix.isNotEmpty) suffix,
    ];

    final fullName = nameParts.join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Your Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Full Name', fullName),
              const Divider(height: 20),
              _buildSummaryRow('Email Address', _emailController.text.trim()),
            ],
          ),
        ),

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onRegisterPressed,
            style: _primaryButtonStyle(),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? 'N/A' : value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _onGoogleSignInPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryRed,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_logo.png',
                    height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _isSubmitting || _isGoogleLoading
              ? null
              : () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
          child: const Text(
            'Log In',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryRed,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryRed,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
    );
  }
}
