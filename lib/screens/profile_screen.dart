import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_back_button.dart';
import '../widgets/member_avatar.dart';
import 'auth_gate.dart';

const _maxBioLength = 160;
const _maxPhotoBytes = 180 * 1024;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _bioController = TextEditingController();
  bool _bioLoaded = false;
  DateTime? _lastUsernameAttempt;

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

  Future<void> _pickAvatarColor(String uid, Color current) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose avatar color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in AppColors.avatarPalette)
              InkWell(
                onTap: () => Navigator.of(context).pop(c),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: c.toARGB32() == current.toARGB32()
                        ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                        : null,
                  ),
                  child: c.toARGB32() == current.toARGB32()
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final db = ref.read(firestoreProvider);
    await db.collection('users').doc(uid).set({'color': picked.toARGB32()}, SetOptions(merge: true));
    ref.invalidate(currentMemberProvider);
  }

  // Secondary avatar options (color, remove photo) go through a dialog —
  // that's fine for them since they don't need a native file picker.
  // Uploading a photo does NOT go through this dialog: browsers only
  // honor a file <input>.click() as a genuine user gesture when it
  // happens with no `await` gaps back to the original tap, and a
  // showDialog round-trip (itself async, resolving on a later frame)
  // breaks that chain — the picker would silently no-op. So the camera
  // button below calls _uploadPhoto directly instead.
  Future<void> _avatarOptionsMenu(String uid, Color currentColor, bool hasPhoto) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Avatar options'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('color'),
            child: const Text('Pick a color'),
          ),
          if (hasPhoto)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('remove'),
              child: const Text('Remove photo', style: TextStyle(color: AppColors.priorityHigh)),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'color':
        await _pickAvatarColor(uid, currentColor);
      case 'remove':
        await ref.read(firestoreProvider).collection('users').doc(uid).update({'photoBase64': FieldValue.delete()});
    }
  }

  Future<void> _uploadPhoto(String uid) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the photo picker: $e')));
      }
      return;
    }
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file could not be read as an image.')),
        );
      }
      return;
    }

    // Downscale to a small square-ish thumbnail — this is stored inline
    // on the user doc (no Firebase Storage, which now requires the paid
    // Blaze plan even for free-tier usage), so it needs to stay well
    // under Firestore's 1 MiB document limit regardless of the source
    // photo's size.
    final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longestSide > 256
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 256 : null,
            height: decoded.height > decoded.width ? 256 : null,
          )
        : decoded;

    var quality = 82;
    var jpg = img.encodeJpg(resized, quality: quality);
    while (jpg.length > _maxPhotoBytes && quality > 25) {
      quality -= 15;
      jpg = img.encodeJpg(resized, quality: quality);
    }
    if (jpg.length > _maxPhotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That photo is too large even after compression — try a different one.')),
        );
      }
      return;
    }

    await ref.read(firestoreProvider).collection('users').doc(uid).set(
      {'photoBase64': base64Encode(jpg)},
      SetOptions(merge: true),
    );
  }

  Future<void> _editUsername(String uid, String? currentUsername) async {
    final controller = TextEditingController(text: currentUsername ?? '');
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '@',
            hintText: 'letters, numbers, underscore',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (newUsername == null || newUsername.isEmpty || !mounted) return;

    // A light client-side cooldown against rapid-fire claim attempts —
    // the real race-safety guarantee is the `create`-only Firestore rule,
    // this just blunts someone scripting a tight retry loop against it.
    final now = DateTime.now();
    if (_lastUsernameAttempt != null && now.difference(_lastUsernameAttempt!) < const Duration(seconds: 3)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slow down a moment before trying another username.')),
      );
      return;
    }
    _lastUsernameAttempt = now;

    final error = await claimUsername(ref.read(firestoreProvider), uid, newUsername, previousUsername: currentUsername);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Username set to @${newUsername.toLowerCase()}')),
    );
  }

  Future<void> _linkGoogle() async {
    final auth = ref.read(firebaseAuthProvider);
    try {
      await auth.currentUser!.linkWithPopup(GoogleAuthProvider());
      if (mounted) {
        ref.invalidate(currentMemberProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account linked — you can now sign in with Google.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'credential-already-in-use'
          ? 'That Google account is already linked to a different FlowBoard account.'
          : friendlyAuthErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
                final photoBase64 = snap.data?.data()?['photoBase64'] as String?;
                final hasPhoto = photoBase64 != null && photoBase64.isNotEmpty;
                final username = snap.data?.data()?['username'] as String?;
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
                          AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                          const SizedBox(width: 12),
                          Text('Profile', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _avatarOptionsMenu(me.id, me.color, hasPhoto),
                            tooltip: 'Avatar options',
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
                              child: Tooltip(
                                message: 'Upload photo',
                                child: InkWell(
                                  onTap: () => _uploadPhoto(me.id),
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
                        child: InkWell(
                          onTap: () => _editUsername(me.id, username),
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            username != null && username.isNotEmpty ? '@$username' : 'Set a username',
                            style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w600),
                          ),
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
                      if (user != null && user.isAnonymous) ...[
                        const SizedBox(height: 24),
                        Text('ACCOUNT', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _linkGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                          ),
                          child: Text(
                            'Link Google account to save this guest profile',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
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
