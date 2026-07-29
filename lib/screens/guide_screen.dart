import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _channel = MethodChannel('com.deploydulupulangnanti.fakegpspro/location');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enable Mock Location'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.gps_fixed, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'How to enable Mock Location',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _stepCard(
            1,
            'Enable Developer Options',
            'Settings → About Phone → Tap "Build Number" 7 times',
            Icons.settings,
            () => _openSettings(context, 'about'),
          ),
          const SizedBox(height: 12),
          _stepCard(
            2,
            'Open Developer Options',
            'Settings → System → Developer Options',
            Icons.developer_mode,
            () => _openSettings(context, 'dev'),
          ),
          const SizedBox(height: 12),
          _stepCard(
            3,
            'Select Mock Location App',
            'Scroll to "Select mock location app"\n→ Choose "Fake GPS PRO"',
            Icons.location_on,
            null,
          ),
          const SizedBox(height: 12),
          _stepCard(
            4,
            'Start Spoofing',
            'Go back to app\n→ Enter coordinates\n→ Tap "Spoof"',
            Icons.play_circle,
            null,
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If "Select mock location app" doesn\'t appear,\nyour device may not support mock location\nor use a custom ROM.',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _stepCard(int step, String title, String desc, IconData icon, VoidCallback? onTap) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$step')),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: onTap != null
            ? IconButton(icon: const Icon(Icons.open_in_new), onPressed: onTap)
            : Icon(icon, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, String type) async {
    try {
      await _channel.invokeMethod('openSettings', {'type': type});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'dev'
                  ? 'Open Settings → System → Developer Options manually'
                  : 'Open Settings → About Phone → Tap Build Number 7 times',
            ),
          ),
        );
      }
    }
  }
}
