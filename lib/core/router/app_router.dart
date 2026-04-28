import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/portal/presentation/pages/activities_page.dart';
import '../../features/portal/presentation/pages/explore_page.dart';
import '../../features/portal/presentation/pages/message_center_page.dart';
import '../../features/portal/presentation/pages/parent_contact_page.dart';
import '../../features/portal/presentation/pages/review_center_page.dart';
import '../../features/portal/presentation/pages/review_detail_page.dart';
import '../../features/portal/presentation/pages/student_release_lab_page.dart';
import '../../features/portal/presentation/pages/task_detail_page.dart';
import '../../features/school/presentation/pages/school_entry_page.dart';
import '../../features/school/presentation/pages/school_selection_page.dart';
import '../../features/school/presentation/providers/school_context_provider.dart';
import '../../features/student/presentation/pages/student_identity_selection_page.dart';
import '../../features/student/presentation/providers/student_identity_provider.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../../features/users/presentation/pages/user_detail_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/home/presentation/pages/ui_showcase_page.dart';
import '../../features/home/presentation/pages/skeleton_showcase_page.dart';
import '../../features/home/presentation/pages/error_showcase_page.dart';
import '../../features/home/presentation/pages/file_upload_showcase_page.dart';
import '../../features/home/presentation/pages/language_showcase_page.dart';
import '../../features/forms/presentation/pages/forms_example_page.dart';
import '../../shared/widgets/responsive_scaffold.dart';

final onboardingCompletedProvider = StateProvider<bool>((ref) {
  // This will be updated when onboarding is completed
  return false;
});

final _onboardingInitProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final completed = prefs.getBool('onboarding_completed') ?? false;

  // Update the state provider with the loaded value
  Future.microtask(() {
    ref.read(onboardingCompletedProvider.notifier).state = completed;
  });

  return completed;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);
  final schoolSelectionRequired = ref
      .watch(schoolSelectionRequiredProvider)
      .maybeWhen(data: (value) => value, orElse: () => false);
  final studentIdentitySelectionRequired = ref
      .watch(studentIdentitySelectionRequiredProvider)
      .maybeWhen(data: (value) => value, orElse: () => false);

  // Initialize onboarding state from preferences
  ref.watch(_onboardingInitProvider);

  return GoRouter(
    initialLocation: onboardingCompleted
        ? (authState.isAuthenticated ? '/home' : '/login')
        : '/onboarding',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isSchoolEntryRoute = state.matchedLocation.startsWith('/s/');
      final isSchoolSelectionRoute = state.matchedLocation == '/school-select';
      final isStudentSelectionRoute =
          state.matchedLocation == '/student-select';

      // Check onboarding first for new users
      if (!onboardingCompleted && !isOnboardingRoute && !isSchoolEntryRoute) {
        return '/onboarding';
      }

      if (onboardingCompleted &&
          !isAuthenticated &&
          !isAuthRoute &&
          !isSchoolEntryRoute &&
          !isSchoolSelectionRoute &&
          !isStudentSelectionRoute) {
        return '/login';
      }

      if (isAuthenticated &&
          studentIdentitySelectionRequired &&
          !isStudentSelectionRoute &&
          !isSchoolEntryRoute) {
        return '/student-select';
      }

      if (isAuthenticated &&
          !studentIdentitySelectionRequired &&
          isStudentSelectionRoute) {
        return '/home';
      }

      if (isAuthenticated &&
          schoolSelectionRequired &&
          !isSchoolSelectionRoute &&
          !isSchoolEntryRoute &&
          !isStudentSelectionRoute) {
        return '/school-select';
      }

      if (isAuthenticated &&
          !schoolSelectionRequired &&
          isSchoolSelectionRoute) {
        return '/home';
      }

      // Redirect authenticated users away from auth pages
      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/school-select',
        builder: (context, state) => const SchoolSelectionPage(),
      ),
      GoRoute(
        path: '/student-select',
        builder: (context, state) => const StudentIdentitySelectionPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/s/:schoolCode',
        builder: (context, state) {
          final schoolCode = state.pathParameters['schoolCode']!;
          return SchoolEntryPage(schoolCode: schoolCode);
        },
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/activities',
        builder: (context, state) => const ActivitiesPage(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessageCenterPage(),
      ),
      GoRoute(
        path: '/reviews',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return ReviewCenterPage(
            activityTitle: query['activityTitle'],
            className: query['className'],
          );
        },
      ),
      GoRoute(
        path: '/reviews/:reviewId',
        builder: (context, state) {
          final reviewId = state.pathParameters['reviewId']!;
          final query = state.uri.queryParameters;
          return ReviewDetailPage(
            reviewId: reviewId,
            title: query['title'] ?? '查看点评',
            belongTo: query['belongTo'] ?? '英语学习',
            teacher: query['teacher'] ?? '老师',
          );
        },
      ),
      GoRoute(
        path: '/activities/:activityId',
        pageBuilder: (context, state) {
          final activityId = state.pathParameters['activityId']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: TaskDetailPage(activityId: activityId),
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                    reverseCurve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.985,
                        end: 1,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          );
        },
        routes: [
          GoRoute(
            path: 'parent-contact',
            builder: (context, state) {
              final activityId = state.pathParameters['activityId']!;
              return ParentContactPage(activityId: activityId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) =>
            ExplorePage(initialTab: state.uri.queryParameters['tab']),
      ),
      GoRoute(
        path: '/student-release-lab',
        builder: (context, state) => const StudentReleaseLabPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ResponsiveScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  return UserDetailPage(userId: userId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/showcase/ui',
            builder: (context, state) => const UIShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/skeletons',
            builder: (context, state) => const SkeletonShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/errors',
            builder: (context, state) => const ErrorShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/upload',
            builder: (context, state) => const FileUploadShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/language',
            builder: (context, state) => const LanguageShowcasePage(),
          ),
          GoRoute(
            path: '/forms',
            builder: (context, state) => const FormsExamplePage(),
          ),
        ],
      ),
    ],
  );
});
