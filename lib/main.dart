import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ สำคัญ

import 'firebase_options.dart';

// pages/services ของคุณ
import 'pages/splash_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/home/student_home_page.dart';
import 'pages/home/admin_home_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ ต้อง await ตรงนี้ก่อนใช้งาน DateFormat('th_TH')
  await initializeDateFormatting('th_TH', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CourseApp());
}

class CourseApp extends StatelessWidget {
  const CourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      useMaterial3: true,
      textTheme: GoogleFonts.kanitTextTheme(),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Course Enrollment',
      theme: baseTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // ยังโหลด session auth อยู่
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        // ยังไม่ล็อกอิน -> ไปหน้า Login
        if (!snap.hasData) {
          return const LoginPage();
        }

        // ล็อกอินแล้ว -> ดู role ใน Firestore
        return FutureBuilder(
          future: AuthService().getCurrentAppUser(),
          builder: (context, userSnap) {
            // error ตอนดึง profile? พาผู้ใช้ไป StudentHomePage ปกติ
            if (userSnap.hasError) {
              return StudentHomePage();
            }

            // ยังโหลด profile -> splash
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const SplashPage();
            }

            // ถ้าไม่มี profile ใน /users/{uid} → treat เป็น student
            if (!userSnap.hasData || userSnap.data == null) {
              return StudentHomePage();
            }

            final appUser = userSnap.data!;
            final role = appUser.role; // 'admin' หรือ 'student'

            if (role == 'admin') {
              return const AdminHomePage();
            } else {
              return StudentHomePage();
            }
          },
        );
      },
    );
  }
}
