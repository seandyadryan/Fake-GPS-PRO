import '../l10n/l10n.dart';
import '../models/location_message.dart';
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
  LocationMessage? _error;
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
      final results = await GeocodingService.search(
        _search.text.trim(),
        languageCode: context.l10n.localeName.replaceAll('_', '-'),
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? LocationMessage.searchNotFound : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = LocationMessage.searchFailed);
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
                Text(
                  context.l10n.exploreLocations,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              if (!compact) SizedBox(height: 12),
              TabBar(
                tabs: [
                  Tab(
                    text: context.l10n.search,
                    icon: compact ? null : Icon(Icons.search),
                  ),
                  Tab(
                    text: context.l10n.saved,
                    icon: compact ? null : Icon(Icons.bookmark_border),
                  ),
                  Tab(
                    text: context.l10n.history,
                    icon: compact ? null : Icon(Icons.history),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _find(),
                            decoration: InputDecoration(
                              hintText: context.l10n.searchHint,
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: IconButton(
                                onPressed: _loading ? null : _find,
                                icon: Icon(Icons.arrow_forward),
                              ),
                            ),
                          ),
                          if (_loading)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            ),
                          if (_error != null)
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(_error!.localize(context.l10n)),
                            ),
                          Expanded(
                            child: _results.isNotEmpty
                                ? ListView.builder(
                                    itemCount: _results.length,
                                    itemBuilder: (_, i) {
                                      final result = _results[i];
                                      return ListTile(
                                        leading: Icon(
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
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Text(
                                          context.l10n.quickPlaces,
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
                                          _city(
                                            context.l10n.jakarta,
                                            -6.2088,
                                            106.8456,
                                          ),
                                          _city(
                                            context.l10n.bandung,
                                            -6.9175,
                                            107.6191,
                                          ),
                                          _city(
                                            context.l10n.surabaya,
                                            -7.2575,
                                            112.7521,
                                          ),
                                          _city(
                                            context.l10n.bali,
                                            -8.3405,
                                            115.0920,
                                          ),
                                          _city(
                                            context.l10n.tokyo,
                                            35.6762,
                                            139.6503,
                                          ),
                                          _city(
                                            context.l10n.london,
                                            51.5074,
                                            -.1278,
                                          ),
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
                            context.l10n.noSavedLocations,
                            context.l10n.savedLocationsHint,
                          )
                        : ListView.builder(
                            itemCount: storage.savedLocations.length,
                            itemBuilder: (_, i) {
                              final loc = storage.savedLocations[i];
                              return ListTile(
                                leading: Icon(Icons.location_on_outlined),
                                title: Text(loc.name),
                                subtitle: Text(
                                  '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                                ),
                                onTap: () =>
                                    _select(loc.latitude, loc.longitude),
                                trailing: IconButton(
                                  tooltip: context.l10n.deleteLocation,
                                  icon: Icon(Icons.delete_outline),
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
                                          SnackBar(
                                            content: Text(
                                              context.l10n.deleteFailed,
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
                            context.l10n.noHistory,
                            context.l10n.historyHint,
                          )
                        : ListView.builder(
                            itemCount: storage.history.length,
                            itemBuilder: (_, i) {
                              final entry = storage.history[i];
                              final date = entry.timestamp;
                              return ListTile(
                                leading: Icon(Icons.history),
                                title: Text(
                                  entry.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  formatHistoryTimestamp(
                                    MaterialLocalizations.of(context),
                                    date,
                                    alwaysUse24HourFormat:
                                        MediaQuery.alwaysUse24HourFormatOf(
                                          context,
                                        ),
                                  ),
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
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
