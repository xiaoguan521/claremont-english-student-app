import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../widgets/onboarding_step.dart';
import '../../../../core/router/app_router.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();
    final schoolName = schoolContext.displayName.isEmpty
        ? '你的学校'
        : schoolContext.displayName;
    final steps = [
      OnboardingStepData(
        title: schoolContext.welcomeTitle,
        description: schoolContext.welcomeMessage,
        image: Icons.school_rounded,
        color: schoolContext.primaryColor,
        logoUrl: schoolContext.logoUrl,
      ),
      OnboardingStepData(
        title: '$schoolName 的英语学习入口',
        description: '这里会同步老师布置的今日主线、班级动态和点评反馈，孩子打开后先完成最重要的一件事。',
        image: Icons.auto_stories_rounded,
        color: schoolContext.secondaryColor,
        logoUrl: schoolContext.logoUrl,
      ),
      const OnboardingStepData(
        title: '作业流程更清楚',
        description: '打开教材、听示范、录音提交，一条链路完成今天的英语打卡，不会再找不到入口。',
        image: Icons.mic_rounded,
        color: Colors.teal,
      ),
      const OnboardingStepData(
        title: 'AI 初评 + 老师复核',
        description: '提交录音后会先进入 AI 初评，再由老师复核，让你更快看到发音建议和鼓励反馈。',
        image: Icons.graphic_eq_rounded,
        color: Colors.orange,
      ),
      const OnboardingStepData(
        title: '准备开始今天的任务',
        description: '进入首页后先看今日主线，再去探索学习地图、查看老师反馈和自己的学习进度。',
        image: Icons.star_rounded,
        color: Color(0xFF68C96A),
      ),
    ];
    final viewportWidth = MediaQuery.of(context).size.width;
    final previousPlaceholderWidth = responsiveClampedValue(
      viewportWidth * 0.18,
      min: 84,
      max: 112,
    );

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: steps.length,
            itemBuilder: (context, index) {
              return OnboardingStep(data: steps[index], index: index);
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: const Text('跳过'),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Page indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    steps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        OutlinedButton(
                          onPressed: _previousPage,
                          child: const Text('上一步'),
                        )
                      else
                        SizedBox(width: previousPlaceholderWidth),
                      FilledButton(
                        onPressed: _currentPage == steps.length - 1
                            ? _completeOnboarding
                            : _nextPage,
                        child: Text(
                          _currentPage == steps.length - 1 ? '开始使用' : '下一步',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        ref.read(onboardingCompletedProvider.notifier).state = true;

        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        context.go('/home');
      }
    }
  }
}

class OnboardingStepData {
  final String title;
  final String description;
  final IconData image;
  final Color color;
  final String logoUrl;

  const OnboardingStepData({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
    this.logoUrl = '',
  });
}
