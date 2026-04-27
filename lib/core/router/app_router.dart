import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/portal/presentation/pages/activities_page.dart';
import '../../features/portal/presentation/pages/explore_page.dart';
import '../../features/portal/presentation/pages/parent_contact_page.dart';
import '../../features/portal/presentation/pages/student_release_lab_page.dart';
import '../../features/portal/presentation/pages/task_detail_page.dart';
import '../../features/school/presentation/pages/school_entry_page.dart';
import '../../features/school/presentation/pages/school_selection_page.dart';
import '../../features/school/presentation/providers/school_context_provider.dart';
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

      // Check onboarding first for new users
      if (!onboardingCompleted && !isOnboardingRoute && !isSchoolEntryRoute) {
        return '/onboarding';
      }

      if (onboardingCompleted &&
          !isAuthenticated &&
          !isAuthRoute &&
          !isSchoolEntryRoute &&
          !isSchoolSelectionRoute) {
        return '/login';
      }

      if (isAuthenticated &&
          schoolSelectionRequired &&
          !isSchoolSelectionRoute &&
          !isSchoolEntryRoute) {
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
        path: '/activities/:activityId',
        builder: (context, state) {
          final activityId = state.pathParameters['activityId']!;
          return TaskDetailPage(activityId: activityId);
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
        builder: (context, state) => const ExplorePage(),
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
