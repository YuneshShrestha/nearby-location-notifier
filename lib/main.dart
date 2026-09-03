import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/notification_service.dart';
import 'services/background_task_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  // Lets this (UI) isolate receive callbacks/status from the foreground
  // service's isolate. Must be called before any FlutterForegroundTask use.
  FlutterForegroundTask.initCommunicationPort();

  // WorkManager registration is idempotent (ExistingPeriodicWorkPolicy.keep),
  // so it's safe to call this on every app start.
  await BackgroundTaskService.initialize();
  await BackgroundTaskService.start();

  runApp(const NearbyNotifierApp());
}

class NearbyNotifierApp extends StatelessWidget {
  const NearbyNotifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Notifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const PermissionGate(child: HomeScreen()),
    );
  }
}

/// Requests the permissions geofencing needs before showing the app.
/// Location "while in use" is requested first, then "always" (background),
/// since Android requires them to be requested in that order, plus the
/// notification permission on Android 13+.
class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _ready = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final whileInUse = await Permission.locationWhenInUse.request();
    if (!whileInUse.isGranted) {
      setState(() => _problem =
          'Location permission is required for nearby alerts to work.');
      return;
    }

    // Background location must be requested after foreground location,
    // and Android shows its own separate "Allow all the time" screen.
    final always = await Permission.locationAlways.request();

    await Permission.notification.request();

    if (!always.isGranted) {
      setState(() => _problem =
          'For alerts to work while the app is closed, choose "Allow all '
          'the time" for location in the next system dialog or in '
          'Settings > Apps > Nearby Notifier > Permissions > Location.');
      // We still let the app proceed — foreground monitoring will work,
      // background monitoring may be limited until this is granted.
    }

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready && _problem == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                  onPressed: () {
                    setState(() => _problem = null);
                    _requestPermissions();
                  },
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

    return widget.child;
  }
}
