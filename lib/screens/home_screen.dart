import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/storage_provider.dart';
import '../services/geocoding_service.dart';
import '../models/saved_location.dart';
import '../models/location_history.dart';
import 'guide_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _saveNameController = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final location = ref.read(locationProvider.notifier);
    location.getCurrentLocation();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _searchController.dispose();
    _saveNameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _updateMarkerAndCamera(LatLng pos) {
    _mapController.move(pos, 15);
  }

  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    ref.read(locationProvider.notifier).setPosition(position);
    _latController.text = position.latitude.toStringAsFixed(6);
    _lngController.text = position.longitude.toStringAsFixed(6);
    _updateMarkerAndCamera(position);
  }

  void _searchCoordinates() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showSnackBar('Invalid coordinates');
      return;
    }
    ref.read(locationProvider.notifier).setPosition(LatLng(lat, lng));
    _updateMarkerAndCamera(LatLng(lat, lng));
  }

  Future<void> _searchByPlaceName() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      final results = await GeocodingService.search(query);
      if (results.isEmpty) {
        _showSnackBar('Location not found');
        return;
      }
      final loc = results.first;
      final pos = LatLng(loc.latitude, loc.longitude);
      ref.read(locationProvider.notifier).setPosition(pos);
      _latController.text = loc.latitude.toStringAsFixed(6);
      _lngController.text = loc.longitude.toStringAsFixed(6);
      _updateMarkerAndCamera(pos);
      if (!mounted) return;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Search failed: $e');
    }
  }

  Future<void> _toggleMockLocation() async {
    final msg = await ref.read(locationProvider.notifier).toggleMockMode(
      _latController.text,
      _lngController.text,
    );
    _showSnackBar(msg);
    if (msg.contains('Developer Options')) {
      _showGuideDialog();
    }
  }

  void _addSimulationPoint() {
    ref.read(locationProvider.notifier).addSimulationPoint();
    final state = ref.read(locationProvider);
    _showSnackBar('Point added (${state.simulationPath.length} total)');
  }

  void _startSimulation() {
    final state = ref.read(locationProvider);
    if (state.simulationPath.length < 2) {
      _showSnackBar('Tap multiple points on map first');
      return;
    }
    ref.read(locationProvider.notifier).startSimulation();
  }

  void _stopSimulation() {
    ref.read(locationProvider.notifier).addSimulationPoint(); // hack to trigger stop
    _showSnackBar('Simulation stopped');
  }

  Future<void> _saveCurrentLocation() async {
    final name = _saveNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Enter a name for this location');
      return;
    }
    final pos = ref.read(locationProvider).currentPosition;
    await ref.read(storageProvider.notifier).saveLocation(name, pos.latitude, pos.longitude);
    _saveNameController.clear();
    _showSnackBar('Location saved');
  }

  Future<void> _deleteSavedLocation(String id) async {
    await ref.read(storageProvider.notifier).deleteLocation(id);
  }

  void _goToLocation(SavedLocation loc) {
    final pos = LatLng(loc.latitude, loc.longitude);
    ref.read(locationProvider.notifier).setPosition(pos);
    _latController.text = loc.latitude.toStringAsFixed(6);
    _lngController.text = loc.longitude.toStringAsFixed(6);
    _updateMarkerAndCamera(pos);
    Navigator.of(context).pop();
  }

  void _goToHistory(LocationHistory entry) {
    final pos = LatLng(entry.latitude, entry.longitude);
    ref.read(locationProvider.notifier).setPosition(pos);
    _latController.text = entry.latitude.toStringAsFixed(6);
    _lngController.text = entry.longitude.toStringAsFixed(6);
    _updateMarkerAndCamera(pos);
    Navigator.of(context).pop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
    );
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Mock Location'),
        content: const Text('You need to select "Fake GPS PRO" as the mock location app in Developer Options.\n\nOpen Settings → Developer Options → Select mock location app'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const GuideScreen())); }, child: const Text('Show Guide')),
        ],
      ),
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _buildBottomSheetContent(ctx),
    );
  }

  Widget _buildBottomSheetContent(BuildContext ctx) {
    final storageState = ref.watch(storageProvider);
    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.search), text: 'Search'),
                Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
              labelColor: Theme.of(ctx).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSearchTab(ctx),
                  _buildSavedTab(ctx, storageState),
                  _buildHistoryTab(ctx, storageState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(BuildContext ctx) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search place name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onSubmitted: (_) => _searchByPlaceName(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _searchByPlaceName, icon: const Icon(Icons.search)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _quickChip('Jakarta', () => _quickSearch(ctx, -6.2088, 106.8456)),
                  _quickChip('Bandung', () => _quickSearch(ctx, -6.9175, 107.6191)),
                  _quickChip('Surabaya', () => _quickSearch(ctx, -7.2575, 112.7521)),
                  _quickChip('Bali', () => _quickSearch(ctx, -8.3405, 115.0920)),
                  _quickChip('Tokyo', () => _quickSearch(ctx, 35.6762, 139.6503)),
                  _quickChip('London', () => _quickSearch(ctx, 51.5074, -0.1278)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), onPressed: onTap, padding: const EdgeInsets.symmetric(horizontal: 4));
  }

  void _quickSearch(BuildContext ctx, double lat, double lng) {
    final pos = LatLng(lat, lng);
    ref.read(locationProvider.notifier).setPosition(pos);
    _latController.text = lat.toStringAsFixed(6);
    _lngController.text = lng.toStringAsFixed(6);
    _updateMarkerAndCamera(pos);
    Navigator.of(ctx).pop();
  }

  Widget _buildSavedTab(BuildContext ctx, StorageState storageState) {
    if (storageState.savedLocations.isEmpty) {
      return const Center(child: Text('No saved locations yet'));
    }
    return ListView.builder(
      itemCount: storageState.savedLocations.length,
      itemBuilder: (ctx, i) {
        final loc = storageState.savedLocations[i];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(loc.name),
          subtitle: Text('${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteSavedLocation(loc.id)),
          onTap: () => _goToLocation(loc),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext ctx, StorageState storageState) {
    if (storageState.history.isEmpty) {
      return const Center(child: Text('No history yet'));
    }
    return ListView.builder(
      itemCount: storageState.history.length,
      itemBuilder: (ctx, i) {
        final entry = storageState.history[i];
        return ListTile(
          leading: const Icon(Icons.access_time, color: Colors.grey),
          title: Text(entry.address, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${entry.latitude.toStringAsFixed(4)}, ${entry.longitude.toStringAsFixed(4)}'),
          trailing: Text('${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          onTap: () => _goToHistory(entry),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    _latController.text = locationState.currentPosition.latitude.toStringAsFixed(6);
    _lngController.text = locationState.currentPosition.longitude.toStringAsFixed(6);

    final markers = [
      Marker(
        point: locationState.currentPosition,
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(Icons.location_on, color: locationState.isMocking ? Colors.green : Colors.blue, size: 40),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake GPS PRO', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuideScreen())),
            tooltip: 'Mock Location Guide',
          ),
          if (locationState.isSimulating)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          Icon(locationState.isMocking ? Icons.gps_fixed : Icons.gps_not_fixed, color: locationState.isMocking ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locationState.currentPosition,
                    initialZoom: 15,
                    onTap: _onMapTapped,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.deploydulupulangnanti.fake_gps_pro',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  top: 16, right: 16,
                  child: Column(
                    children: [
                      _mapBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.my_location, () => ref.read(locationProvider.notifier).getCurrentLocation()),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.menu, _showBottomSheet),
                    ],
                  ),
                ),
                if (locationState.isMocking)
                  Positioned(
                    top: 16, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                          SizedBox(width: 6),
                          Text('MOCK ACTIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (locationState.simulationPath.isNotEmpty)
                  Positioned(
                    top: 16, left: 80,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                      child: Text('Route: ${locationState.simulationPath.length} pts', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: const Icon(Icons.explore_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: const Icon(Icons.explore_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _actionBtn(Icons.search, 'Set', _searchCoordinates, false),
                    _actionBtn(
                      locationState.isMocking ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
                      locationState.isMocking ? 'Stop' : 'Spoof',
                      _toggleMockLocation, locationState.isLoading,
                      color: locationState.isMocking ? Colors.red : Colors.green,
                    ),
                    _actionBtn(Icons.route, 'Route', _addSimulationPoint, false),
                    _actionBtn(
                      locationState.isSimulating ? Icons.stop : Icons.play_arrow,
                      locationState.isSimulating ? 'StopR' : 'Simulate',
                      locationState.isSimulating ? _stopSimulation : _startSimulation, false,
                      color: locationState.isSimulating ? Colors.red : Colors.orange,
                    ),
                    _actionBtn(Icons.save, 'Save', () => _showSaveDialog(), false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onPressed, bool loading, {Color? color}) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onPressed) {
    return FloatingActionButton.small(heroTag: icon.codePoint.toString(), onPressed: onPressed, child: Icon(icon, size: 20));
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Location'),
        content: TextField(
          controller: _saveNameController,
          decoration: const InputDecoration(hintText: 'Location name', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(ctx); _saveCurrentLocation(); }, child: const Text('Save')),
        ],
      ),
    );
  }
}
