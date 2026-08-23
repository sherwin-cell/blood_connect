import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/services/firestore_service.dart';
import 'features/verification/domain/services/i_face_embedding_service.dart';
import 'features/verification/data/services/tflite_face_embedding_service.dart';
import 'features/verification/data/services/cloudinary_service.dart';
import 'features/verification/data/services/face_detector_service.dart';
import 'features/verification/data/services/ocr_service.dart';
import 'features/verification/data/repositories/verification_repository_impl.dart';
import 'features/verification/domain/repositories/i_verification_repository.dart';
import 'features/verification/presentation/provider/verification_provider.dart';
import 'features/verification/presentation/screens/verification_pending_screen.dart';

import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/email_verification_screen.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pre-initialize the TFLite interpreter
  final tfliteService = TFLiteFaceEmbeddingService();
  await tfliteService.initialize();

  runApp(BloodConnectApp(faceEmbeddingService: tfliteService));
}

class BloodConnectApp extends StatelessWidget {
  final IFaceEmbeddingService faceEmbeddingService;

  const BloodConnectApp({super.key, required this.faceEmbeddingService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Core Services
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<CloudinaryService>(create: (_) => CloudinaryService()),
        Provider<OcrService>(create: (_) => OcrService()),
        Provider<FaceDetectorService>(create: (_) => FaceDetectorService()),

        // 2. Production TFLite Face Embedding Service Instance
        Provider<IFaceEmbeddingService>.value(value: faceEmbeddingService),

        // 3. Verification Repository Injection
        ProxyProvider5<
          OcrService,
          FaceDetectorService,
          CloudinaryService,
          FirestoreService,
          IFaceEmbeddingService,
          IVerificationRepository
        >(
          update:
              (
                _,
                ocr,
                faceDetector,
                cloudinary,
                firestore,
                faceEmbedding,
                __,
              ) => VerificationRepositoryImpl(
                ocrService: ocr,
                faceDetectorService: faceDetector,
                cloudinaryService: cloudinary,
                firestoreService: firestore,
                faceEmbeddingService: faceEmbedding,
              ),
        ),

        // 4. UI State Provider
        ChangeNotifierProxyProvider<
          IVerificationRepository,
          VerificationProvider
        >(
          create: (context) => VerificationProvider(
            repository: context.read<IVerificationRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? VerificationProvider(repository: repo),
        ),
      ],
      child: MaterialApp(
        title: 'Blood-Connect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: const _AppStartupSplash(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/auth-gate': (context) => const AuthGate(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/verify-email': (context) => const EmailVerificationScreen(),
          '/verification-pending': (context) =>
              const VerificationPendingScreen(),
        },
      ),
    );
  }
}

class _AppStartupSplash extends StatefulWidget {
  const _AppStartupSplash();

  @override
  State<_AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<_AppStartupSplash> {
  @override
  void initState() {
    super.initState();
    _navigateToAuthGate();
  }

  Future<void> _navigateToAuthGate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
