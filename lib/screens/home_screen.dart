import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/mock_location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(-6.2088, 106.8456);
  Set<Marker> _markers = {};
  bool _isMocking = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationAlways,
    ].request();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
            title: _isMocking ? 'Mock Location' : 'Real Location',
            snippet:
                '${_currentPosition.latitude}, ${_currentPosition.longitude}',
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
    if (lat == null || lng == null) {
      _showSnackBar('Invalid coordinates');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showSnackBar('Coordinates out of range');
      return;
    }
    setState(() {
      _currentPosition = LatLng(lat, lng);
    });
    _updateMarkerAndCamera();
  }

  Future<void> _toggleMockLocation() async {
    if (_isMocking) {
      final success = await MockLocationService.disableMockMode();
      if (success) {
        setState(() => _isMocking = false);
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
      final enabled = await MockLocationService.enableMockMode();
      if (enabled) {
        final success = await MockLocationService.setMockLocation(lat, lng);
        if (success) {
          setState(() {
            _isMocking = true;
            _currentPosition = LatLng(lat, lng);
          });
          _updateMarkerAndCamera();
          _showSnackBar('Mock location activated');
        }
      }
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fake GPS PRO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Icon(
            _isMocking ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: _isMocking ? Colors.green : Colors.grey,
          ),
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
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: _onMapTapped,
                  markers: _markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: true,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: () => _mapController?.animateCamera(
                          CameraUpdate.zoomIn(),
                        ),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: () => _mapController?.animateCamera(
                          CameraUpdate.zoomOut(),
                        ),
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        onPressed: _getCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                if (_isMocking)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: Colors.white, size: 12),
                          SizedBox(width: 6),
                          Text(
                            'MOCK ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
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
                          prefixIcon: const Icon(Icons.explore_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: const Icon(Icons.explore_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _searchCoordinates,
                        icon: const Icon(Icons.search),
                        label: const Text('Set Location'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _toggleMockLocation,
                        icon: Icon(
                          _isMocking
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outlined,
                        ),
                        label: Text(
                          _isMocking ? 'Stop Spoof' : 'Start Spoof',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _isMocking
                              ? Colors.red
                              : Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
