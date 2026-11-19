import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/services/firestore_service.dart';
import 'core/services/push_notification_service.dart';

import 'features/verification/domain/services/i_face_embedding_service.dart';
import 'features/verification/data/services/tflite_face_embedding_service.dart';
import 'features/verification/data/services/cloudinary_service.dart';
import 'features/verification/data/services/face_detector_service.dart';
import 'features/verification/data/repositories/verification_repository_impl.dart';
import 'features/verification/domain/repositories/i_verification_repository.dart';
import 'features/verification/presentation/provider/verification_provider.dart';

import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/email_verification_screen.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/donor/presentation/screens/donor_pending_screen.dart';

/// Application entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase before using Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Register the background FCM handler before runApp().
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Initialize push notifications and notification listeners.
  await PushNotificationService.instance.initialize();

  // 4. Initialize the face embedding service.
  final tfliteService = TFLiteFaceEmbeddingService();
  await tfliteService.initialize();

  // 5. Start the application.
  runApp(BloodConnectApp(faceEmbeddingService: tfliteService));
}

class BloodConnectApp extends StatelessWidget {
  final IFaceEmbeddingService faceEmbeddingService;

  const BloodConnectApp({super.key, required this.faceEmbeddingService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services.
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<CloudinaryService>(create: (_) => CloudinaryService()),
        Provider<FaceDetectorService>(create: (_) => FaceDetectorService()),

        // Face embedding service.
        Provider<IFaceEmbeddingService>.value(value: faceEmbeddingService),

        // Verification repository.
        ProxyProvider4<
          FaceDetectorService,
          CloudinaryService,
          FirestoreService,
          IFaceEmbeddingService,
          IVerificationRepository
        >(
          update:
              (context, faceDetector, cloudinary, firestore, faceEmbedding, _) {
                return VerificationRepositoryImpl(
                  faceDetectorService: faceDetector,
                  cloudinaryService: cloudinary,
                  firestoreService: firestore,
                  faceEmbeddingService: faceEmbedding,
                );
              },
        ),

        // Verification state provider.
        ChangeNotifierProxyProvider<
          IVerificationRepository,
          VerificationProvider
        >(
          create: (context) => VerificationProvider(
            repository: context.read<IVerificationRepository>(),
          ),
          update: (_, repository, previous) {
            return previous ?? VerificationProvider(repository: repository);
          },
        ),
      ],
      child: MaterialApp(
        title: 'Blood-Connect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: const _AppStartupSplash(),
        routes: {
          '/welcome': (_) => const WelcomeScreen(),
          '/auth-gate': (_) => const AuthGate(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/verify-email': (_) => const EmailVerificationScreen(),
          '/donor-pending': (_) => const DonorPendingScreen(),
        },
      ),
    );
  }
}

/// Displays the startup splash screen before opening the authentication gate.
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
