import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/ai/camera_control_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/profile_model.dart';
import '../../../providers/profile_provider.dart';
import '../../admin/controllers/admin_role_controller.dart';
import '../models/settings_state.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure persisted settings are loaded (idempotent; keeps prefs in sync).
    Future.microtask(() => ref.read(settingsProvider.notifier).read());

    final settings = ref.watch(settingsProvider);
    final profileAsync = ref.watch(profileProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          _AccountCard(profileAsync),
          const SizedBox(height: 24),

          // Admin-only. The section is hidden for learners, and the router
          // guard blocks /admin even if a link slips through.
          if (isAdmin) ...[
            const _SectionHeader(title: 'Administration'),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _AdminTile(
                  onTap: () => _openAdmin(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          const _SectionHeader(title: 'Practice'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.vibration,
                title: 'Haptic feedback',
                subtitle: 'Vibrate when a sign is mastered',
                value: settings.hapticFeedback,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setHapticFeedback(v),
              ),
              const _Divider(),
              _SwitchTile(
                icon: Icons.volume_up_outlined,
                title: 'Sound effects',
                subtitle: 'Play a sound when a sign is mastered',
                value: settings.soundEffects,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setSoundEffects(v),
              ),
              const _Divider(),
              _SwitchTile(
                icon: Icons.skip_next_outlined,
                title: 'Auto-advance signs',
                subtitle: 'Move to the next sign automatically in focus mode',
                value: settings.autoAdvance,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setAutoAdvance(v),
              ),
              const _Divider(),
              _SegmentTile(
                icon: Icons.timer_outlined,
                title: 'Hold to confirm',
                subtitle:
                    'How long a sign must be held steady before it counts as completed',
                value: settings.holdToConfirm.label,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in HoldToConfirm.values) ...[
                        _ChoiceChip(
                          label: option.label,
                          selected:
                              settings.holdToConfirm == option,
                          onSelected: () => ref
                              .read(settingsProvider.notifier)
                              .setHoldToConfirm(option),
                        ),
                        if (option != HoldToConfirm.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionHeader(title: 'Camera'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SegmentTile(
                icon: Icons.camera_alt_outlined,
                title: 'Default camera',
                subtitle:
                    'Camera used during sign practice',
                value: settings.cameraLens == CameraLens.back
                    ? 'Back'
                    : 'Front',
                children: [
                  _ChoiceChip(
                    label: 'Front',
                    selected: settings.cameraLens == CameraLens.front,
                    onSelected: () => _setLens(ref, CameraLens.front),
                  ),
                  const SizedBox(width: 8),
                  _ChoiceChip(
                    label: 'Back',
                    selected: settings.cameraLens == CameraLens.back,
                    onSelected: () => _setLens(ref, CameraLens.back),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionHeader(title: 'About'),
          const SizedBox(height: 8),
          const _SettingsCard(
            children: [
              _AboutTile(
                icon: Icons.info_outline,
                title: 'Version',
                trailing: '1.0.0',
              ),
              _Divider(),
              _AboutTile(
                icon: Icons.feedback_outlined,
                title: 'Send feedback',
                trailing: '',
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _setLens(WidgetRef ref, CameraLens lens) async {
    await ref.read(settingsProvider.notifier).setCameraLens(lens);
    await CameraControlService.setLensFacing(lens);
  }

  /// Confirms admin access before navigating.
  ///
  /// The role is re-read rather than trusted from the cached value, so an admin
  /// who was demoted in another session cannot walk in on a stale cache. If
  /// access is gone the section disappears on the next rebuild instead of the
  /// user bouncing off the router guard.
  Future<void> _openAdmin(BuildContext context, WidgetRef ref) async {
    final role = await ref.read(adminRoleProvider.notifier).refresh(force: true);

    if (!context.mounted) return;

    if (!role.isAdmin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You no longer have admin access.'),
          ),
        );
      return;
    }

    context.push(AppRoutes.admin);
  }
}

/// Entry point into the admin area, shown only to admins.
class _AdminTile extends StatelessWidget {
  const _AdminTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.admin_panel_settings_outlined,
          color: AppColors.primary),
      title: const Text(
        'Admin console',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      subtitle: const Text(
        'Analytics, learners, curriculum and activity log',
        style: TextStyle(color: AppColors.subtitle),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subtitle),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.subtitle,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AsyncValue<ProfileModel?> profileAsync;
  const _AccountCard(this.profileAsync);

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        profileAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Unable to load account'),
          ),
          data: (profile) {
            final name = profile?.fullName ?? 'Signer';
            final email = profile?.email ?? '';
            return _AccountTile(name: name, email: email);
          },
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String name;
  final String email;
  const _AccountTile({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(
            Icons.person,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.subtitle),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<Widget> children;

  const _SegmentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.subtitle,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: children),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      trailing: trailing.isEmpty
          ? const Icon(Icons.chevron_right,
              size: 20, color: Colors.grey)
          : Text(
              trailing,
              style: const TextStyle(
                color: AppColors.subtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}
