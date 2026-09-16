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
          const SnackBar(
            content: Text('Buka Pengaturan perangkat secara manual.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(locationProvider).setup;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Siapkan perangkat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, const Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: Colors.white, size: 40),
                SizedBox(height: 16),
                Text(
                  'Siap dalam beberapa langkah',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Android mengharuskan Developer Mode aktif dan Fake GPS PRO dipilih sebagai aplikasi mock location.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (setup?.supported == false)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Spoof lokasi hanya tersedia di Android.'),
            ),
          _step(
            context,
            1,
            'Aktifkan Developer Mode',
            'Buka Tentang ponsel → Informasi perangkat lunak → ketuk Nomor bentukan / Build number 7 kali. Nama menu dapat berbeda di tiap merek.',
            setup?.developerEnabled == true,
            'Buka Tentang ponsel',
            () => _open(context, 'about'),
          ),
          _step(
            context,
            2,
            'Pilih aplikasi mock location',
            'Di Opsi pengembang / Developer Options, aktifkan sakelar utama. Buka Pilih aplikasi lokasi palsu / Select mock location app, lalu pilih Fake GPS PRO.',
            setup?.mockAppSelected == true,
            'Buka Developer Options',
            () => _open(context, 'dev'),
          ),
          _step(
            context,
            3,
            'Aktifkan lokasi perangkat',
            'Layanan lokasi perangkat harus aktif sebelum spoof dimulai.',
            setup?.locationEnabled == true,
            'Buka pengaturan lokasi',
            () => _open(context, 'location'),
          ),
          _step(
            context,
            4,
            'Izinkan akses lokasi',
            'Pilih Izinkan saat aplikasi digunakan. Jika izin pernah diblokir, ubah lewat pengaturan aplikasi.',
            setup?.locationPermissionGranted == true,
            'Atur izin lokasi',
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  }
                }
                await ref.read(locationProvider.notifier).refreshStatus();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Buka izin lokasi di pengaturan aplikasi.'),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(locationProvider.notifier).refreshStatus();
              if (!context.mounted) return;
              if (ref.read(locationProvider).setup?.ready == true) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lengkapi pengaturan yang belum aktif.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Periksa kesiapan'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Setelah siap, kembali ke peta lalu tekan Mulai spoof. Gunakan Stop mock location di aplikasi atau notifikasi untuk menghentikannya. GPS mungkin perlu beberapa saat untuk mendapatkan lokasi asli.',
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
