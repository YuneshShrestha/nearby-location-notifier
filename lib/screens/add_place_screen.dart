import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/place.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '180');

  bool _locating = false;

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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Turn on device location and try again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission is needed to use your current spot.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    } catch (e) {
      _showError('Couldn\'t get current location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final place = Place(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_lngController.text.trim()),
      radiusMeters: double.parse(_radiusController.text.trim()),
    );

    Navigator.of(context).pop(place);
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add place')),
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
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Use my current location'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  helperText: 'You\'ll be notified when you enter this radius',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _numberValidator,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Save place'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
