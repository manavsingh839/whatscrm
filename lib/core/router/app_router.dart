import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/agents/screens/agents_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/join_invite_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/automations/screens/automations_screen.dart';
import '../../features/broadcasts/screens/broadcasts_screen.dart';
import '../../features/contacts/screens/contacts_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/flows/screens/flows_screen.dart';
import '../../features/inbox/screens/inbox_screen.dart';
import '../../features/pipelines/screens/pipelines_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/webhooks/screens/webhooks_screen.dart';
import '../../features/shell/app_shell.dart';
import '../config/supabase_config.dart';
import '../../services/supabase_service.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/inbox',
  redirect: (context, state) {
    final isAuthenticated = SupabaseService.isAuthenticated;
    final isAuthRoute = state.uri.path == '/login' ||
        state.uri.path == '/signup' ||
        state.uri.path == '/forgot-password' ||
        state.uri.path.startsWith('/join');

    // If Supabase is not configured yet or in demo testing, allow browsing
    if (!SupabaseConfig.isConfigured) {
      return null;
    }

    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    if (isAuthenticated && isAuthRoute) {
      return '/inbox';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/join/:token',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return JoinInviteScreen(token: token);
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(
          currentRoute: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (context, state) {
            final convId = state.uri.queryParameters['id'] ?? (state.extra as String?);
            return InboxScreen(initialConversationId: convId);
          },
        ),
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const ContactsScreen(),
        ),
        GoRoute(
          path: '/pipelines',
          builder: (context, state) => const PipelinesScreen(),
        ),
        GoRoute(
          path: '/broadcasts',
          builder: (context, state) => const BroadcastsScreen(),
        ),
        GoRoute(
          path: '/automations',
          builder: (context, state) => const AutomationsScreen(),
        ),
        GoRoute(
          path: '/flows',
          builder: (context, state) => const FlowsScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/agents',
          builder: (context, state) => const AgentsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/webhooks',
          builder: (context, state) => const WebhooksScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
