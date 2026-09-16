import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/location_provider.dart';
import '../providers/storage_provider.dart';
import 'guide_screen.dart';
import 'location_library_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final TileProvider? tileProvider;
  const HomeScreen({super.key, this.tileProvider});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _saveNameController = TextEditingController();
  final _mapController = MapController();
  bool _mapReady = false;
  bool _locating = false;

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
    _mapController.dispose();
    super.dispose();
  }

  void _syncCoordinates(LatLng pos) {
    _latController.text = pos.latitude.toStringAsFixed(6);
    _lngController.text = pos.longitude.toStringAsFixed(6);
    if (_mapReady) _mapController.move(pos, _mapController.camera.zoom);
  }

  void _select(LatLng pos) {
    ref.read(locationProvider.notifier).setPosition(pos);
    _syncCoordinates(pos);
  }

  void _message(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  void _guide() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GuideScreen()),
  );

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
      _message('Koordinat tidak valid. Latitude −90…90, longitude −180…180.');
    }
    return pos;
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final message = await ref
        .read(locationProvider.notifier)
        .startMock(_latController.text, _lngController.text);
    if (!mounted) return;
    _message(message);
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
    if (error != null) _message(error);
  }

  Future<void> _save() async {
    final pos = _enteredPosition();
    if (pos == null) return;
    final controller = _saveNameController..clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan lokasi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nama lokasi',
            hintText: 'Contoh: Kantor Jakarta',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    try {
      await ref
          .read(storageProvider.notifier)
          .saveLocation(name, pos.latitude, pos.longitude);
      _message('Lokasi disimpan.');
    } catch (_) {
      _message('Lokasi gagal disimpan. Coba lagi.');
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
          padding: const EdgeInsets.all(10),
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fake GPS PRO',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(
              'Pilih titik. Atur lokasi.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _guide,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Panduan & pengaturan',
          ),
          const SizedBox(width: 6),
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
              padding: const EdgeInsets.all(20),
              child: _controls(state),
            );
            if (landscape) {
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 0, 12),
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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

  Widget _map(LocationState state) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: state.currentPosition,
            initialZoom: 15,
            minZoom: 2,
            maxZoom: 19,
            onMapReady: () => _mapReady = true,
            onTap: (_, position) => _select(position),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileProvider: widget.tileProvider,
              userAgentPackageName: 'com.deploydulupulangnanti.fake_gps_pro',
            ),
            if (state.simulationPath.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.simulationPath,
                    strokeWidth: 4,
                    color: colors.primary.withValues(alpha: .65),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < state.simulationPath.length; i++)
                  Marker(
                    point: state.simulationPath[i],
                    width: 26,
                    height: 26,
                    child: CircleAvatar(
                      backgroundColor: colors.primary,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(color: colors.onPrimary, fontSize: 11),
                      ),
                    ),
                  ),
                if (state.isMocking && state.activePosition != null)
                  Marker(
                    point: state.activePosition!,
                    width: 64,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D9488).withValues(alpha: .20),
                        border: Border.all(
                          color: const Color(0xFF0D9488),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.gps_fixed,
                        color: Color(0xFF0D9488),
                        size: 28,
                      ),
                    ),
                  ),
                Marker(
                  point: state.currentPosition,
                  width: 44,
                  height: 52,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.location_pin,
                    color: colors.primary,
                    size: 48,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 64,
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
                    const Expanded(
                      child: Text(
                        'Cari tempat atau lokasi tersimpan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 10,
          child: Column(
            children: [
              _mapButton(
                Icons.add,
                'Perbesar peta',
                () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom + 1).clamp(2, 19),
                ),
              ),
              const SizedBox(height: 8),
              _mapButton(
                Icons.remove,
                'Perkecil peta',
                () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom - 1).clamp(2, 19),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 28,
          right: 10,
          child: _mapButton(
            _locating ? Icons.hourglass_top : Icons.my_location,
            'Lokasi perangkat',
            _locating ? null : _locate,
          ),
        ),
        Positioned(
          bottom: 6,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFCCFBF1)
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                active ? Icons.gps_fixed : Icons.location_on_outlined,
                color: active ? const Color(0xFF0F766E) : colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'Mock location aktif' : 'Lokasi pilihan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    active
                        ? 'Pilih titik baru lalu perbarui spoof'
                        : 'Ketuk peta atau masukkan koordinat',
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
                color: active ? const Color(0xFF0D9488) : colors.outline,
              ),
            ),
          ],
        ),
        if (active && state.activePosition != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Aktif: ${state.activePosition!.latitude.toStringAsFixed(6)}, ${state.activePosition!.longitude.toStringAsFixed(6)}',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
            ),
          ),
        const SizedBox(height: 12),
        Material(
          color: ready
              ? colors.secondaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _guide,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(ready ? Icons.verified_outlined : Icons.tune, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.setup == null
                          ? 'Memeriksa pengaturan perangkat…'
                          : state.setup?.supported == false
                          ? 'Spoof tersedia di Android saja'
                          : ready
                          ? 'Perangkat siap • Pengaturan'
                          : 'Siapkan Developer Mode & mock location',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
        if (active || state.setup?.hasProviders == true) ...[
          const SizedBox(height: 12),
          _stopButton(state),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _coordinateField(
                _latController,
                'Latitude',
                '−90 hingga 90',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _coordinateField(
                _lngController,
                'Longitude',
                '−180 hingga 180',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  final pos = _enteredPosition();
                  if (pos != null) _select(pos);
                },
                icon: const Icon(Icons.center_focus_strong, size: 18),
                label: const Text('Lihat titik'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Simpan'),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: state.isLoading || state.setup?.supported == false
              ? null
              : _start,
          icon: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(active ? Icons.sync : Icons.play_arrow_rounded),
          label: Text(active ? 'Perbarui spoof' : 'Mulai spoof'),
        ),
        const SizedBox(height: 8),
        if (!active && state.setup?.hasProviders != true) _stopButton(state),
        const SizedBox(height: 8),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(Icons.route_outlined, color: colors.primary),
            title: const Text(
              'Simulasi rute',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${state.simulationPath.length} titik • ${state.isSimulating ? 'Sedang berjalan' : 'Interval 3 detik'}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              const Text(
                'Pilih titik di peta, lalu tambahkan ke rute. Simulasi berpindah antartitik setiap 3 detik.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
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
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Tambah titik'),
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
                              if (error != null) _message(error);
                            }
                          },
                    icon: Icon(
                      state.isSimulating ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(state.isSimulating ? 'Stop rute' : 'Jalankan'),
                  ),
                  TextButton(
                    onPressed: state.simulationPath.isEmpty || state.isLoading
                        ? null
                        : ref.read(locationProvider.notifier).clearRoute,
                    child: const Text('Hapus rute'),
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
              _message(await ref.read(locationProvider.notifier).stopMock()),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
    icon: const Icon(Icons.stop_circle_outlined),
    label: const Text('Stop mock location'),
  );

  Widget _coordinateField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) {
      final pos = _enteredPosition();
      if (pos != null) _select(pos);
    },
    decoration: InputDecoration(labelText: label, hintText: hint),
    inputFormatters: [LengthLimitingTextInputFormatter(24)],
  );
}
