import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/flowboard_logo.dart';
import '../models/member.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      title: 'Organize visually',
      body: 'Columns, cards and priorities that read at a glance. Drag work across the board as it moves.',
    ),
    _OnboardingPageData(
      title: 'Work together, live',
      body: 'See who is on the board, where their cursor is, and what changed the moment it happens.',
    ),
    _OnboardingPageData(
      title: 'Let AI break it down',
      body: 'Turn a vague card into a concrete checklist. Accept the subtasks you want, edit the rest.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const FlowBoardWordmark(iconSize: 24),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text('Skip', style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage(data: _pages[0], illustration: const _OrganizeIllustration()),
                  _OnboardingPage(data: _pages[1], illustration: const _CollabIllustration()),
                  _OnboardingPage(data: _pages[2], illustration: const _AiIllustration()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Get started' : 'Next',
                          style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String body;
  const _OnboardingPageData({required this.title, required this.body});
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final Widget illustration;
  const _OnboardingPage({required this.data, required this.illustration});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(height: 260, child: Center(child: illustration)),
          const Spacer(flex: 2),
          Text(data.title, style: AppTextStyles.h1(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 10),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(height: 1.5),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

const _milo = Member(id: 'milo', name: 'Milo', initials: 'MS', color: AppColors.priorityHigh);
const _jun = Member(id: 'jun', name: 'Jun', initials: 'JL', color: AppColors.priorityLow);

class _OrganizeIllustration extends StatelessWidget {
  const _OrganizeIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget card(Color rule, double h) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: rule, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
    );
    Widget column(String label, List<Widget> cards) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.metaTiny(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...cards,
          ],
        ),
      ),
    );
    return SizedBox(
      width: 260,
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column('TO DO', [card(AppColors.priorityMedium, 34), card(AppColors.priorityLow, 24)]),
          const SizedBox(width: 8),
          column('DOING', [card(AppColors.priorityHigh, 34)]),
        ],
      ),
    );
  }
}

class _CollabIllustration extends StatelessWidget {
  const _CollabIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border(left: const BorderSide(color: AppColors.priorityHigh, width: 3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.priorityHighBg, borderRadius: BorderRadius.circular(6)),
                    child: Text('HIGH', style: AppTextStyles.badge(color: AppColors.priorityHighText).copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('editing now', style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _CursorPill(member: _milo),
          ),
          Positioned(
            left: 10,
            bottom: 20,
            child: _CursorPill(member: _jun),
          ),
          Positioned(
            right: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(7)),
              child: Text('LIVE', style: AppTextStyles.metaSmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CursorPill extends StatelessWidget {
  final Member member;
  const _CursorPill({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: member.color, borderRadius: BorderRadius.circular(999)),
      child: Text(member.name, style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _AiIllustration extends StatelessWidget {
  const _AiIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = ['Define the presence payload schema', 'Interpolate cursor positions client-side'];
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: const BorderSide(color: AppColors.priorityMedium, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(child: Text('Refine onboarding copy', style: AppTextStyles.bodySemibold(color: theme.colorScheme.onSurface))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
                  child: Text('AI', style: AppTextStyles.metaSmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: theme.dividerColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 11, color: Colors.white),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(items[i], style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface))),
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
}
