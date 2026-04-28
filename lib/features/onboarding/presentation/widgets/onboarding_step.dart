import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pages/onboarding_page.dart';

class OnboardingStep extends StatelessWidget {
  final OnboardingStepData data;
  final int index;

  const OnboardingStep({super.key, required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final logoUrl = data.logoUrl.trim();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.color.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data.image,
                size: logoUrl.isEmpty ? 120 : 44,
                color: data.color,
              ).animate().scale(
                delay: 200.ms,
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),
              if (logoUrl.isNotEmpty)
                Container(
                      margin: const EdgeInsets.only(top: 18),
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: data.color.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(data.image, color: data.color, size: 54),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 240.ms, duration: 500.ms)
                    .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 48),
              Text(
                data.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
