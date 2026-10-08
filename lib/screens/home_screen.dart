import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../models/location_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../providers/storage_provider.dart';
import 'guide_screen.dart';
import 'location_library_sheet.dart';
import 'language_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, LocationState state)? mapBuilder;
  const HomeScreen({super.key, this.mapBuilder});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _saveNameController = TextEditingController();
  GoogleMapController? _mapController;
  bool _mapReady = false;
  bool _locating = false;

  bool get _apiKeyMissing =>
      AppConfig.googleMapsApiKey.isEmpty ||
      AppConfig.googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCoordinates(ref.read(locationProvider).currentPosition);
    Future.microtask(() {
      if (mounted) ref.read(locationProvider.notifier).monitorStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationProvider.notifier).refreshStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _latController.dispose();
    _lngController.dispose();
    _saveNameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _syncCoordinates(LatLng pos) {
    _latController.text = pos.latitude.toStringAsFixed(6);
    _lngController.text = pos.longitude.toStringAsFixed(6);
    if (_mapReady && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  void _select(LatLng pos) {
    ref.read(locationProvider.notifier).setPosition(pos);
    _syncCoordinates(pos);
  }

  void _notice(LocationMessage? message) {
    if (mounted && message != null) _message(message.localize(context.l10n));
  }

  void _message(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  void _guide() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => GuideScreen()));

  void _library() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LocationLibrarySheet(onSelect: _select),
  );

  LatLng? _enteredPosition() {
    final pos = LocationNotifier.parseCoordinates(
      _latController.text,
      _lngController.text,
    );
    if (pos == null) {
      _message(context.l10n.invalidCoordinates);
    }
    return pos;
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final message = await ref
        .read(locationProvider.notifier)
        .startMock(_latController.text, _lngController.text);
    if (!mounted) return;
    _notice(message);
    final setup = ref.read(locationProvider).setup;
    if (setup != null && setup.supported && !setup.ready) _guide();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final error = await ref
        .read(locationProvider.notifier)
        .getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (error != null) _notice(error);
  }

  Future<void> _save() async {
    final pos = _enteredPosition();
    if (pos == null) return;
    final controller = _saveNameController..clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.saveLocation),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: context.l10n.locationName,
            hintText: context.l10n.locationNameHint,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LanguageScreen()),
            ),
            icon: const Icon(Icons.language),
            tooltip: context.l10n.language,
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    try {
      await ref
          .read(storageProvider.notifier)
          .saveLocation(name, pos.latitude, pos.longitude);
      if (mounted) _message(context.l10n.locationSaved);
    } catch (_) {
      if (mounted) _message(context.l10n.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationProvider);
    ref.listen(
      locationProvider.select((s) => s.currentPosition),
      (_, next) => _syncCoordinates(next),
    );
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.explore_rounded,
              color: colors.onPrimary,
              size: 24,
            ),
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fake GPS PRO',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(
              context.l10n.tagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _guide,
            icon: Icon(Icons.help_outline_rounded),
            tooltip: context.l10n.guideAndSettings,
          ),
          SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth > 650 && constraints.maxHeight < 600;
            final map = ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _map(state),
            );
            final controls = SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: _controls(state),
            );
            if (landscape) {
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 0, 12),
                      child: map,
                    ),
                  ),
                  SizedBox(width: 350, child: controls),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: map,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .60,
                  ),
                  child: controls,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(LocationState state, ColorScheme colors) {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('selected_pin'),
        position: state.currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: context.l10n.selectedLocation,
          snippet:
              '${state.currentPosition.latitude.toStringAsFixed(6)}, ${state.currentPosition.longitude.toStringAsFixed(6)}',
        ),
      ),
    );

    if (state.isMocking && state.activePosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('active_mock'),
          position: state.activePosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(title: context.l10n.mockActiveTitle),
        ),
      );
    }

    for (var i = 0; i < state.simulationPath.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('sim_waypoint_$i'),
          position: state.simulationPath[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(LocationState state, ColorScheme colors) {
    if (state.simulationPath.isEmpty) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('simulation_path'),
        points: state.simulationPath,
        width: 4,
        color: colors.primary.withValues(alpha: .75),
      ),
    };
  }

  Widget _map(LocationState state) {
    final colors = Theme.of(context).colorScheme;
    if (widget.mapBuilder != null) {
      return widget.mapBuilder!(context, state);
    }
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: state.currentPosition,
            zoom: 15,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(2, 20),
          onMapCreated: (controller) {
            _mapController = controller;
            _mapReady = true;
          },
          onTap: (pos) => _select(pos),
          markers: _buildMarkers(state, colors),
          polylines: _buildPolylines(state, colors),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
        PositionedDirectional(
          top: 12,
          start: 12,
          end: 64,
          child: Material(
            color: colors.surface,
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _library,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colors.primary, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.searchPlaces,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 12,
          end: 10,
          child: Column(
            children: [
              _mapButton(
                Icons.add,
                context.l10n.zoomIn,
                () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
              ),
              const SizedBox(height: 8),
              _mapButton(
                Icons.remove,
                context.l10n.zoomOut,
                () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          bottom: 28,
          end: 10,
          child: _mapButton(
            _locating ? Icons.hourglass_top : Icons.my_location,
            context.l10n.deviceLocation,
            _locating ? null : _locate,
          ),
        ),
        if (_apiKeyMissing)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.amber.shade900.withValues(alpha: 0.92),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Google Maps API Key belum diatur. Jalankan setup_api_key.ps1 atau tambahkan di AndroidManifest.xml',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapButton(IconData icon, String tooltip, VoidCallback? onPressed) =>
      Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          tooltip: tooltip,
        ),
      );

  Widget _controls(LocationState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ready = state.setup?.ready == true;
    final active = state.isMocking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active ? Color(0xFFCCFBF1) : colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                active ? Icons.gps_fixed : Icons.location_on_outlined,
                color: active ? Color(0xFF0F766E) : colors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? context.l10n.mockActiveTitle
                        : context.l10n.selectedLocation,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    active
                        ? context.l10n.updateLocationHint
                        : context.l10n.selectLocationHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Color(0xFF0D9488) : colors.outline,
              ),
            ),
          ],
        ),
        if (active && state.activePosition != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.activeCoordinates(
                '\u2066${state.activePosition!.latitude.toStringAsFixed(6)}, ${state.activePosition!.longitude.toStringAsFixed(6)}\u2069',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
            ),
          ),
        SizedBox(height: 12),
        Material(
          color: ready
              ? colors.secondaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _guide,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(ready ? Icons.verified_outlined : Icons.tune, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.setup == null
                          ? context.l10n.checkingSettings
                          : state.setup?.supported == false
                          ? context.l10n.androidOnly
                          : ready
                          ? context.l10n.deviceReady
                          : context.l10n.setupRequired,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              state.error!.localize(context.l10n),
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
        if (active || state.setup?.hasProviders == true) ...[
          SizedBox(height: 12),
          _stopButton(state),
        ],
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _coordinateField(
                _latController,
                context.l10n.latitude,
                context.l10n.latitudeRange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _coordinateField(
                _lngController,
                context.l10n.longitude,
                context.l10n.longitudeRange,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  final pos = _enteredPosition();
                  if (pos != null) _select(pos);
                },
                icon: Icon(Icons.center_focus_strong, size: 18),
                label: Text(context.l10n.viewPoint),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _save,
                icon: Icon(Icons.bookmark_border, size: 18),
                label: Text(context.l10n.save),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: state.isLoading || state.setup?.supported == false
              ? null
              : _start,
          icon: state.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(active ? Icons.sync : Icons.play_arrow_rounded),
          label: Text(
            active ? context.l10n.updateMock : context.l10n.startMock,
          ),
        ),
        SizedBox(height: 8),
        if (!active && state.setup?.hasProviders != true) _stopButton(state),
        SizedBox(height: 8),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.only(bottom: 8),
            leading: Icon(Icons.route_outlined, color: colors.primary),
            title: Text(
              context.l10n.routeSimulation,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${context.l10n.routePoints(state.simulationPath.length)} • ${state.isSimulating ? context.l10n.routeRunning : context.l10n.routeInterval}',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              Text(
                context.l10n.routeDescription,
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: state.isSimulating || state.isLoading
                        ? null
                        : () {
                            final pos = _enteredPosition();
                            if (pos == null) return;
                            _select(pos);
                            ref
                                .read(locationProvider.notifier)
                                .addSimulationPoint();
                          },
                    icon: Icon(Icons.add_location_alt_outlined, size: 18),
                    label: Text(context.l10n.addPoint),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            final notifier = ref.read(
                              locationProvider.notifier,
                            );
                            if (state.isSimulating) {
                              notifier.stopSimulation();
                            } else {
                              final error = notifier.startSimulation();
                              if (error != null) _notice(error);
                            }
                          },
                    icon: Icon(
                      state.isSimulating ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(
                      state.isSimulating
                          ? context.l10n.stopRoute
                          : context.l10n.runRoute,
                    ),
                  ),
                  TextButton(
                    onPressed: state.simulationPath.isEmpty || state.isLoading
                        ? null
                        : ref.read(locationProvider.notifier).clearRoute,
                    child: Text(context.l10n.clearRoute),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stopButton(LocationState state) => OutlinedButton.icon(
    onPressed:
        state.isLoading ||
            (!state.isMocking && state.setup?.hasProviders != true)
        ? null
        : () async =>
              _notice(await ref.read(locationProvider.notifier).stopMock()),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
    icon: Icon(Icons.stop_circle_outlined),
    label: Text(context.l10n.stopMock),
  );

  Widget _coordinateField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
    controller: controller,
    textDirection: TextDirection.ltr,
    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) {
      final pos = _enteredPosition();
      if (pos != null) _select(pos);
    },
    decoration: InputDecoration(labelText: label, hintText: hint),
    inputFormatters: [LengthLimitingTextInputFormatter(24)],
  );
}
