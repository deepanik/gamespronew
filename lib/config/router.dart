import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:games_pro/features/auth/presentation/screens/login_screen.dart';
import 'package:games_pro/features/auth/presentation/screens/register_screen.dart';
import 'package:games_pro/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:games_pro/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:games_pro/features/splash/presentation/screens/splash_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/user',
      builder: (context, state) => const UserDashboardScreen(),
    ),
  ],
); 