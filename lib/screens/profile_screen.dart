import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/member_avatar.dart';
import 'auth_gate.dart';

const _maxBioLength = 160;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _bioController = TextEditingController();
  bool _bioLoaded = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _saveBio(String uid) {
    final db = ref.read(firestoreProvider);
    db.collection('users').doc(uid).set({'bio': _bioController.text}, SetOptions(merge: true));
  }

  Future<void> _editName(String uid, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    final db = ref.read(firestoreProvider);
    await db.collection('users').doc(uid).set(
      {'name': newName, 'initials': initialsFor(newName)},
      SetOptions(merge: true),
    );
    if (mounted) ref.invalidate(currentMemberProvider);
  }

  void _photoStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo upload is coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = ref.watch(currentMemberProvider);
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.read(firebaseAuthProvider).currentUser;

    return Scaffold(
      body: SafeArea(
        child: member.when(
          data: (me) {
            final db = ref.watch(firestoreProvider);
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('users').doc(me.id).snapshots(),
              builder: (context, snap) {
                final bio = snap.data?.data()?['bio'] as String? ?? '';
                if (!_bioLoaded && snap.hasData) {
                  _bioController.text = bio;
                  _bioLoaded = true;
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Profile', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Stack(
                          children: [
                            MemberAvatar(member: me, size: 96),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                onTap: _photoStub,
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 1.4),
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: InkWell(
                          onTap: () => _editName(me.id, me.name),
                          borderRadius: BorderRadius.circular(8),
                          child: Text(me.name, style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          user?.email ?? 'Guest account',
                          style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('ONLINE', style: AppTextStyles.metaSmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('BIO', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              maxLength: _maxBioLength,
                              style: AppTextStyles.body(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(border: InputBorder.none, counterText: '', isDense: true),
                              onSubmitted: (_) => _saveBio(me.id),
                              onTapOutside: (_) => _saveBio(me.id),
                            ),
                            Text(
                              '${_bioController.text.length} / $_maxBioLength',
                              style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('THEME', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      _ThemeSelector(
                        mode: themeMode,
                        onChanged: (m) => ref.read(themeModeProvider.notifier).setThemeMode(m),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: () => _editName(me.id, me.name),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                        ),
                        child: Text('Edit Profile', style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            ref.read(currentMemberStateProvider.notifier).state = null;
                            await ref.read(firebaseAuthProvider).signOut();
                            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          child: Text('Sign out', style: AppTextStyles.body(color: AppColors.priorityHigh).copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode mode;
  final void Function(ThemeMode) onChanged;
  const _ThemeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const options = [
      (ThemeMode.light, 'Light'),
      (ThemeMode.dark, 'Dark'),
      (ThemeMode.system, 'System'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (m, label) in options)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(m),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == m ? theme.colorScheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: mode == m
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(
                      fontWeight: mode == m ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
