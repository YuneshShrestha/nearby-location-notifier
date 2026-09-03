import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'services/notification_service.dart';
import 'services/background_task_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  // Allows the UI isolate to communicate with the foreground
  // service isolate.
  FlutterForegroundTask.initCommunicationPort();

  // Initialize background monitoring infrastructure.
  await BackgroundTaskService.initialize();

  runApp(const NearbyNotifierApp());
}

class NearbyNotifierApp extends StatelessWidget {
  const NearbyNotifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Notifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PermissionGate(child: HomeScreen()),
    );
  }
}

class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _ready = false;
  bool _starting = false;

  String? _problem;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (_starting) return;

    _starting = true;

    try {
      setState(() {
        _problem = null;
      });

      // --------------------------------------------------
      // 1. Foreground location permission
      // --------------------------------------------------

      final whileInUse = await Permission.locationWhenInUse.request();

      if (!whileInUse.isGranted) {
        if (!mounted) return;

        setState(() {
          _problem =
              'Location permission is required for nearby alerts to work.';
        });

        return;
      }

      // --------------------------------------------------
      // 2. Background location permission
      // --------------------------------------------------

      final always = await Permission.locationAlways.request();

      // --------------------------------------------------
      // 3. Notification permission
      // --------------------------------------------------

      await Permission.notification.request();

      // --------------------------------------------------
      // 4. Start background monitoring
      // --------------------------------------------------

      await BackgroundTaskService.start();

      if (!mounted) return;

      setState(() {
        _ready = true;

        if (!always.isGranted) {
          _problem =
              'Background location is not enabled. '
              'Nearby alerts may not work when the app is closed.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _problem = 'Something went wrong while setting up permissions: $e';
      });
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permissions.
    if (!_ready && _problem == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Required foreground permission was denied.
    if (!_ready && _problem != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 48),

                const SizedBox(height: 16),

                Text(_problem!, textAlign: TextAlign.center),

                const SizedBox(height: 16),

                FilledButton(
                  onPressed: _starting ? null : _requestPermissions,
                  child: const Text('Try again'),
                ),

                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // App is ready.
    //
    // If background permission was denied, show a warning
    // while still allowing the user to use the app.
    return Stack(
      children: [
        widget.child,

        if (_problem != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Text(
                        'Background location is disabled. '
                        'Alerts may not work when the app is closed.',
                      ),
                    ),

                    TextButton(
                      onPressed: openAppSettings,
                      child: const Text('Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
