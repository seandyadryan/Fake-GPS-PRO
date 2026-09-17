import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../services/mock_location_service.dart';

class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key});

  Future<void> _open(BuildContext context, String type) async {
    try {
      if (!await MockLocationService.openSettings(type)) {
        throw StateError('Settings unavailable');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.openSettingsManually)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(locationProvider).setup;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.setupDevice)),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: Colors.white, size: 40),
                SizedBox(height: 16),
                Text(
                  context.l10n.setupHeadline,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  context.l10n.setupDescription,
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          if (setup?.supported == false)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(context.l10n.androidOnly),
            ),
          _step(
            context,
            1,
            context.l10n.enableDeveloperMode,
            context.l10n.developerInstructions,
            setup?.developerEnabled == true,
            context.l10n.openAboutPhone,
            () => _open(context, 'about'),
          ),
          _step(
            context,
            2,
            context.l10n.selectMockApp,
            context.l10n.mockAppInstructions,
            setup?.mockAppSelected == true,
            context.l10n.openDeveloperOptions,
            () => _open(context, 'dev'),
          ),
          _step(
            context,
            3,
            context.l10n.enableDeviceLocation,
            context.l10n.locationInstructions,
            setup?.locationEnabled == true,
            context.l10n.openLocationSettings,
            () => _open(context, 'location'),
          ),
          _step(
            context,
            4,
            context.l10n.allowLocationAccess,
            context.l10n.permissionInstructions,
            setup?.locationPermissionGranted == true,
            context.l10n.manageLocationPermission,
            () async {
              try {
                final permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.deniedForever) {
                  await Geolocator.openAppSettings();
                } else {
                  final error = await ref
                      .read(locationProvider.notifier)
                      .requestLocationPermission();
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.localize(context.l10n))),
                    );
                  }
                }
                await ref.read(locationProvider.notifier).refreshStatus();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.openAppPermissionSettings),
                    ),
                  );
                }
              }
            },
          ),
          SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(locationProvider.notifier).refreshStatus();
              if (!context.mounted) return;
              if (ref.read(locationProvider).setup?.ready == true) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.completeSetup)),
                );
              }
            },
            icon: Icon(Icons.check_circle_outline),
            label: Text(context.l10n.checkReadiness),
          ),
          SizedBox(height: 18),
          Text(
            context.l10n.afterSetupInstructions,
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context,
    int number,
    String title,
    String description,
    bool done,
    String action,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: done
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  child: done
                      ? Icon(Icons.check, size: 18, color: colors.onPrimary)
                      : Text(
                          '$number',
                          style: TextStyle(color: colors.onSurface),
                        ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
            ),
            SizedBox(height: 8),
            TextButton.icon(
              onPressed: onTap,
              icon: Icon(Icons.open_in_new, size: 16),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
