import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:provider/provider.dart';
import '../Screens/Splash.dart';
import 'Constant/ISSAASProvider.dart';
import 'Constant/controller_weather.dart';
import 'Constant/forget_password_provider.dart';
import 'Constant/login_provider.dart';
import 'Constant/splash_provider.dart';
import 'Screens/device_selection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginProvider>(
          create: (_) => LoginProvider(),
        ),
        ChangeNotifierProvider<ForgotPasswordProvider>(
          create: (_) => ForgotPasswordProvider(),
        ),
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => SplashProvider(),
        ),
        ChangeNotifierProvider<ISSAASProvider>(
          create: (_) => ISSAASProvider(),
        ),
      ],
      child: const MaterialApp(
        title: 'Project Drone',
        home: AuthCheck(), // Determine the initial screen dynamically
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(WeatherController());
    // Check if a user is already signed in
    final User? user = FirebaseAuth.instance.currentUser;

    // If the user is signed in, navigate to the Device screen; otherwise, show SplashScreen
    if (user != null) {
      return DeviceSelection(); // Replace with your Device screen widget
    } else {
      return SplashScreen();
    }
  }
}
