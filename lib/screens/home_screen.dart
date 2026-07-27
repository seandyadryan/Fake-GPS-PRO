import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../services/mock_location_service.dart';
import '../services/storage_service.dart';
import '../models/saved_location.dart';
import '../models/location_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _saveNameController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(-6.2088, 106.8456);
  Set<Marker> _markers = {};
  bool _isMocking = false;
  bool _isLoading = false;
  bool _isSimulating = false;
  Timer? _simulationTimer;
  List<SavedLocation> _savedLocations = [];
  List<LocationHistory> _history = [];
  List<LatLng> _simulationPath = [];
  int _simulationIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getCurrentLocation();
    _loadData();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _searchController.dispose();
    _saveNameController.dispose();
    _mapController?.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final saved = await StorageService.getSavedLocations();
    final history = await StorageService.getHistory();
    if (mounted) {
      setState(() {
        _savedLocations = saved;
        _history = history;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ].request();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
      _updateMarkerAndCamera();
    } catch (e) {
      _updateMarkerAndCamera();
    }
  }

  void _updateMarkerAndCamera() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current_position'),
          position: _currentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isMocking ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueBlue,
          ),
          infoWindow: InfoWindow(
            title: _isMocking ? 'Mock Location' : 'Current Location',
            snippet: '${_currentPosition.latitude}, ${_currentPosition.longitude}',
          ),
        ),
      };
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition, 15),
    );
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _currentPosition = position;
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    });
    _updateMarkerAndCamera();
  }

  void _searchCoordinates() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showSnackBar('Invalid coordinates');
      return;
    }
    setState(() => _currentPosition = LatLng(lat, lng));
    _updateMarkerAndCamera();
  }

  Future<void> _searchByPlaceName() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showSnackBar('Location not found');
        return;
      }
      final loc = locations.first;
      setState(() {
        _currentPosition = LatLng(loc.latitude, loc.longitude);
        _latController.text = loc.latitude.toStringAsFixed(6);
        _lngController.text = loc.longitude.toStringAsFixed(6);
      });
      _updateMarkerAndCamera();
      _searchController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showSnackBar('Search failed: $e');
    }
  }

  Future<void> _toggleMockLocation() async {
    if (_isMocking) {
      final success = await MockLocationService.disableMockMode();
      if (success) {
        setState(() => _isMocking = false);
        _stopSimulation();
        _showSnackBar('Mock location disabled');
      }
    } else {
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);
      if (lat == null || lng == null) {
        _showSnackBar('Enter valid coordinates first');
        return;
      }
      setState(() => _isLoading = true);
      final success = await MockLocationService.enableMockMode(lat, lng);
      if (success) {
        setState(() {
          _isMocking = true;
          _currentPosition = LatLng(lat, lng);
        });
        _updateMarkerAndCamera();
        _addToHistory(lat, lng);
        _showSnackBar('Mock location activated');
      }
      setState(() => _isLoading = false);
    }
  }

  void _startSimulation() {
    if (_simulationPath.length < 2) {
      _showSnackBar('Tap multiple points on map first');
      return;
    }
    setState(() {
      _isSimulating = true;
      _simulationIndex = 0;
    });
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_simulationIndex >= _simulationPath.length) {
        _stopSimulation();
        return;
      }
      final point = _simulationPath[_simulationIndex];
      setState(() {
        _currentPosition = point;
        _latController.text = point.latitude.toStringAsFixed(6);
        _lngController.text = point.longitude.toStringAsFixed(6);
      });
      _updateMarkerAndCamera();
      if (_isMocking) {
        await MockLocationService.setMockLocation(point.latitude, point.longitude);
      }
      _simulationIndex++;
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _simulationPath = [];
      _simulationIndex = 0;
    });
  }

  void _addSimulationPoint() {
    setState(() {
      _simulationPath.add(_currentPosition);
    });
    _showSnackBar('Point added (${_simulationPath.length} total)');
  }

  Future<void> _updateMockLocation() async {
    if (!_isMocking) return;
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return;
    final success = await MockLocationService.setMockLocation(lat, lng);
    if (success) {
      setState(() => _currentPosition = LatLng(lat, lng));
      _updateMarkerAndCamera();
    }
  }

  Future<void> _addToHistory(double lat, double lng) async {
    String address = '$lat, $lng';
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isNotEmpty) {
        final p = places.first;
        address = '${p.street}, ${p.locality}';
      }
    } catch (_) {}
    final entry = LocationHistory(
      id: const Uuid().v4(),
      latitude: lat,
      longitude: lng,
      address: address,
      timestamp: DateTime.now(),
    );
    await StorageService.addHistory(entry);
    final history = await StorageService.getHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _saveCurrentLocation() async {
    final name = _saveNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Enter a name for this location');
      return;
    }
    final location = SavedLocation(
      id: const Uuid().v4(),
      name: name,
      latitude: _currentPosition.latitude,
      longitude: _currentPosition.longitude,
      createdAt: DateTime.now(),
    );
    await StorageService.saveLocation(location);
    _saveNameController.clear();
    final saved = await StorageService.getSavedLocations();
    if (mounted) setState(() => _savedLocations = saved);
    _showSnackBar('Location saved');
  }

  Future<void> _deleteSavedLocation(String id) async {
    await StorageService.deleteLocation(id);
    final saved = await StorageService.getSavedLocations();
    if (mounted) setState(() => _savedLocations = saved);
  }

  void _goToLocation(SavedLocation loc) {
    setState(() {
      _currentPosition = LatLng(loc.latitude, loc.longitude);
      _latController.text = loc.latitude.toStringAsFixed(6);
      _lngController.text = loc.longitude.toStringAsFixed(6);
    });
    _updateMarkerAndCamera();
    Navigator.of(context).pop();
  }

  void _goToHistory(LocationHistory entry) {
    setState(() {
      _currentPosition = LatLng(entry.latitude, entry.longitude);
      _latController.text = entry.latitude.toStringAsFixed(6);
      _lngController.text = entry.longitude.toStringAsFixed(6);
    });
    _updateMarkerAndCamera();
    Navigator.of(context).pop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildBottomSheetContent(ctx),
    );
  }

  Widget _buildBottomSheetContent(BuildContext ctx) {
    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
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
                  _buildSavedTab(ctx),
                  _buildHistoryTab(ctx),
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
            IconButton.filled(
              onPressed: _searchByPlaceName,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _quickSearch(BuildContext ctx, double lat, double lng) {
    setState(() {
      _currentPosition = LatLng(lat, lng);
      _latController.text = lat.toStringAsFixed(6);
      _lngController.text = lng.toStringAsFixed(6);
    });
    _updateMarkerAndCamera();
    Navigator.of(ctx).pop();
  }

  Widget _buildSavedTab(BuildContext ctx) {
    if (_savedLocations.isEmpty) {
      return const Center(child: Text('No saved locations yet'));
    }
    return ListView.builder(
      itemCount: _savedLocations.length,
      itemBuilder: (ctx, i) {
        final loc = _savedLocations[i];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(loc.name),
          subtitle: Text('${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteSavedLocation(loc.id),
          ),
          onTap: () => _goToLocation(loc),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext ctx) {
    if (_history.isEmpty) {
      return const Center(child: Text('No history yet'));
    }
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final entry = _history[i];
        return ListTile(
          leading: const Icon(Icons.access_time, color: Colors.grey),
          title: Text(entry.address),
          subtitle: Text(
            '${entry.latitude.toStringAsFixed(4)}, ${entry.longitude.toStringAsFixed(4)}',
          ),
          trailing: Text(
            '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          onTap: () => _goToHistory(entry),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake GPS PRO', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isSimulating)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          Icon(_isMocking ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _isMocking ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
                  onMapCreated: (c) => _mapController = c,
                  onTap: _onMapTapped,
                  markers: _markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 16, right: 16,
                  child: Column(
                    children: [
                      _mapBtn(Icons.add, () => _mapController?.animateCamera(CameraUpdate.zoomIn())),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.remove, () => _mapController?.animateCamera(CameraUpdate.zoomOut())),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.my_location, _getCurrentLocation),
                      const SizedBox(height: 8),
                      _mapBtn(Icons.menu, _showBottomSheet),
                    ],
                  ),
                ),
                if (_isMocking)
                  Positioned(
                    top: 16, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                if (_simulationPath.isNotEmpty)
                  Positioned(
                    top: 16, left: 80,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Route: ${_simulationPath.length} pts',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
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
                      _isMocking ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
                      _isMocking ? 'Stop' : 'Spoof',
                      _toggleMockLocation,
                      _isLoading,
                      color: _isMocking ? Colors.red : Colors.green,
                    ),
                    _actionBtn(Icons.route, 'Route', _addSimulationPoint, false),
                    _actionBtn(
                      _isSimulating ? Icons.stop : Icons.play_arrow,
                      _isSimulating ? 'StopR' : 'Simulate',
                      _isSimulating ? _stopSimulation : _startSimulation,
                      false,
                      color: _isSimulating ? Colors.red : Colors.orange,
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
    return FloatingActionButton.small(
      heroTag: icon.codePoint.toString(),
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Location'),
        content: TextField(
          controller: _saveNameController,
          decoration: const InputDecoration(
            hintText: 'Location name',
            border: OutlineInputBorder(),
          ),
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
