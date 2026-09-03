import 'package:flutter/material.dart';
import 'package:nearby_users_getter/screens/edit_place_screen.dart';

import '../models/place.dart';
import '../services/storage_service.dart';
import 'add_place_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<Place> _places = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _editPlace(Place place) async {
    final updatedPlace = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => EditPlaceScreen(place: place)),
    );

    if (updatedPlace == null) return;

    setState(() {
      _places = _places
          .map((p) => p.id == updatedPlace.id ? updatedPlace : p)
          .toList();
    });

    await _save();
  }

  Future<void> _load() async {
    final places = await _storage.loadPlaces();
    setState(() {
      _places = places;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _storage.savePlaces(_places);
  }

  Future<void> _addPlace() async {
    final newPlace = await Navigator.of(context)
        .push<Place>(MaterialPageRoute(builder: (_) => const AddPlaceScreen()));
    if (newPlace == null) return;
    setState(() => _places = [..._places, newPlace]);
    await _save();
  }

  Future<void> _toggleActive(Place place, bool value) async {
    setState(() {
      _places = _places
          .map((p) => p.id == place.id ? p.copyWith(active: value) : p)
          .toList();
    });
    await _save();
  }

  Future<void> _delete(Place place) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete place?'),
          content: Text('Are you sure you want to delete "${place.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _places = _places.where((p) => p.id != place.id).toList();
    });

    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Notifier')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
          ? _EmptyState(onAdd: _addPlace)
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final place = _places[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place.name),
                    subtitle: Text(
                      '${place.radiusMeters.toStringAsFixed(0)} m radius · '
                      '${place.latitude.toStringAsFixed(4)}, '
                      '${place.longitude.toStringAsFixed(4)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: place.active,
                          onChanged: (v) => _toggleActive(place, v),
                        ),

                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editPlace(place),
                        ),

                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(place),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlace,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add place'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_searching, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No places yet. Add a fixed place (like your college, a shop, '
              'or a meeting point) and get notified when you\'re nearby — '
              'even if the app is closed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first place'),
            ),
          ],
        ),
      ),
    );
  }
}
