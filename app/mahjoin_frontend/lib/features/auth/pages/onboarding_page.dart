import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/router/router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _page = 0;
  final _controller = PageController();

  static const _steps = [
    _OnboardingStep(
      icon: Icons.location_on_rounded,
      title: '探索附近牌友',
      subtitle:
          '即時查看你 5 公里內正在找牌局的玩家，快速找到同桌夥伴。',
      iconColor: AppColors.primary,
    ),
    _OnboardingStep(
      icon: Icons.people_rounded,
      title: '加入或建立房間',
      subtitle:
          '你可以建立房間等待牌友，也可以直接加入附近現成房間馬上開打。',
      iconColor: AppColors.secondary,
    ),
    _OnboardingStep(
      icon: Icons.star_rounded,
      title: '對局並提升評分',
      subtitle:
          '記錄勝場、累積評分，和你的固定牌咖保持連線。',
      iconColor: AppColors.waiting,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('MahJoin',
                      style: AppTypography.headlineLarge
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _steps.length,
                itemBuilder: (ctx, i) => _StepView(step: _steps[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primary
                        : AppColors.divider,
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  if (_page < _steps.length - 1) ...[
                    ElevatedButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('下一步'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _goToLogin(context),
                      child: Text('略過',
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: () => _goToLogin(context),
                      child: const Text('開始使用'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _goToLogin(BuildContext context) {
    AppRouter.go(context, AppRoutes.login);
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });
}

class _StepView extends StatelessWidget {
  final _OnboardingStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: step.iconColor, size: 56),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(step.title,
              style: AppTypography.displayMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.subtitle,
            style: AppTypography.bodyLarge
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
