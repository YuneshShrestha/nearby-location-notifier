import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class EditPlaceScreen extends StatefulWidget {
  final Place place;

  const EditPlaceScreen({
    super.key,
    required this.place,
  });

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;

  bool _locating = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.place.name,
    );

    _latController = TextEditingController(
      text: widget.place.latitude.toStringAsFixed(6),
    );

    _lngController = TextEditingController(
      text: widget.place.longitude.toStringAsFixed(6),
    );

    _radiusController = TextEditingController(
      text: widget.place.radiusMeters.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();

    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showError(
          'Turn on device location and try again.',
        );
        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showError(
          'Location permission is required.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
          'Location permission is permanently denied. '
          'Please enable it from app settings.',
        );
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      _latController.text =
          position.latitude.toStringAsFixed(6);

      _lngController.text =
          position.longitude.toStringAsFixed(6);
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Couldn\'t get current location: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _nameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a place name';
    }

    return null;
  }

  String? _latitudeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final latitude = double.tryParse(value.trim());

    if (latitude == null) {
      return 'Invalid latitude';
    }

    if (latitude < -90 || latitude > 90) {
      return 'Must be between -90 and 90';
    }

    return null;
  }

  String? _longitudeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final longitude = double.tryParse(value.trim());

    if (longitude == null) {
      return 'Invalid longitude';
    }

    if (longitude < -180 || longitude > 180) {
      return 'Must be between -180 and 180';
    }

    return null;
  }

  String? _radiusValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final radius = double.tryParse(value.trim());

    if (radius == null) {
      return 'Enter a valid number';
    }

    if (radius <= 0) {
      return 'Radius must be greater than 0';
    }

    if (radius < 50) {
      return 'Radius should be at least 50 m';
    }

    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedPlace = widget.place.copyWith(
      name: _nameController.text.trim(),
      latitude: double.parse(
        _latController.text.trim(),
      ),
      longitude: double.parse(
        _lngController.text.trim(),
      ),
      radiusMeters: double.parse(
        _radiusController.text.trim(),
      ),
    );

    Navigator.of(context).pop(updatedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit place'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. College, Shop, Bus stop',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _nameValidator,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _latitudeValidator,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _longitudeValidator,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text(
                    'Use my current location',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  helperText:
                      'You\'ll be notified when you enter this radius',
                  prefixIcon: Icon(
                    Icons.radar_outlined,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _radiusValidator,
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}