import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/storage_provider.dart';
import '../services/geocoding_service.dart';

class LocationLibrarySheet extends ConsumerStatefulWidget {
  final ValueChanged<LatLng> onSelect;
  const LocationLibrarySheet({super.key, required this.onSelect});

  @override
  ConsumerState<LocationLibrarySheet> createState() =>
      _LocationLibrarySheetState();
}

class _LocationLibrarySheetState extends ConsumerState<LocationLibrarySheet> {
  final _search = TextEditingController();
  bool _loading = false;
  String? _error;
  List<GeocodingResult> _results = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(double lat, double lng) {
    widget.onSelect(LatLng(lat, lng));
    Navigator.pop(context);
  }

  Future<void> _find() async {
    if (_loading || _search.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await GeocodingService.search(_search.text.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isEmpty
            ? 'Tempat tidak ditemukan. Coba nama yang lebih lengkap.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pencarian gagal. Periksa koneksi internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;
    final compact = height - keyboard < 420;
    return DefaultTabController(
      length: 3,
      child: SizedBox(
        height: keyboard > 0 ? height - 32 : height * .72,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              if (!compact)
                const Text(
                  'Jelajahi lokasi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              if (!compact) const SizedBox(height: 12),
              TabBar(
                tabs: [
                  Tab(
                    text: 'Cari',
                    icon: compact ? null : const Icon(Icons.search),
                  ),
                  Tab(
                    text: 'Tersimpan',
                    icon: compact ? null : const Icon(Icons.bookmark_border),
                  ),
                  Tab(
                    text: 'Riwayat',
                    icon: compact ? null : const Icon(Icons.history),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _find(),
                            decoration: InputDecoration(
                              hintText: 'Nama tempat, kota, atau alamat',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                onPressed: _loading ? null : _find,
                                icon: const Icon(Icons.arrow_forward),
                              ),
                            ),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_error!),
                            ),
                          Expanded(
                            child: _results.isNotEmpty
                                ? ListView.builder(
                                    itemCount: _results.length,
                                    itemBuilder: (_, i) {
                                      final result = _results[i];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.location_on_outlined,
                                        ),
                                        title: Text(
                                          result.displayName,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => _select(
                                          result.latitude,
                                          result.longitude,
                                        ),
                                      );
                                    },
                                  )
                                : ListView(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Text(
                                          'PILIH CEPAT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _city('Jakarta', -6.2088, 106.8456),
                                          _city('Bandung', -6.9175, 107.6191),
                                          _city('Surabaya', -7.2575, 112.7521),
                                          _city('Bali', -8.3405, 115.0920),
                                          _city('Tokyo', 35.6762, 139.6503),
                                          _city('London', 51.5074, -.1278),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    storage.savedLocations.isEmpty
                        ? _empty(
                            Icons.bookmark_border,
                            'Belum ada lokasi tersimpan',
                            'Simpan titik favorit dari halaman utama.',
                          )
                        : ListView.builder(
                            itemCount: storage.savedLocations.length,
                            itemBuilder: (_, i) {
                              final loc = storage.savedLocations[i];
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(loc.name),
                                subtitle: Text(
                                  '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                                ),
                                onTap: () =>
                                    _select(loc.latitude, loc.longitude),
                                trailing: IconButton(
                                  tooltip: 'Hapus lokasi',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(storageProvider.notifier)
                                          .deleteLocation(loc.id);
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Lokasi gagal dihapus.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                    storage.history.isEmpty
                        ? _empty(
                            Icons.history,
                            'Belum ada riwayat',
                            'Lokasi yang berhasil di-spoof muncul di sini.',
                          )
                        : ListView.builder(
                            itemCount: storage.history.length,
                            itemBuilder: (_, i) {
                              final entry = storage.history[i];
                              final date = entry.timestamp;
                              return ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(
                                  entry.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                ),
                                onTap: () =>
                                    _select(entry.latitude, entry.longitude),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _city(String name, double lat, double lng) =>
      ActionChip(label: Text(name), onPressed: () => _select(lat, lng));
  Widget _empty(IconData icon, String title, String subtitle) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
