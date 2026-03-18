import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(LocationPickerResult) onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(19.4326, -99.1332);
  String _address = 'Obteniendo dirección...';
  bool _loadingAddress = false;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _loadingLocation = false;
      _reverseGeocode(_selectedPosition);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _loadingLocation = false;
            _address = 'Permiso de ubicación denegado';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _address = 'Permiso de ubicación denegado permanentemente';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPosition = newPos;
        _loadingLocation = false;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
      _reverseGeocode(newPos);
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _address = 'No se pudo obtener la ubicación';
      });
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final parts = <String>[
          if (place.street != null && place.street!.isNotEmpty) place.street!,
          if (place.subLocality != null && place.subLocality!.isNotEmpty)
            place.subLocality!,
          if (place.locality != null && place.locality!.isNotEmpty)
            place.locality!,
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty)
            place.administrativeArea!,
        ];
        setState(() {
          _address = parts.isNotEmpty ? parts.join(', ') : 'Dirección no disponible';
          _loadingAddress = false;
        });
        widget.onLocationSelected(LocationPickerResult(
          latitude: position.latitude,
          longitude: position.longitude,
          address: _address,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          _loadingAddress = false;
        });
        widget.onLocationSelected(LocationPickerResult(
          latitude: position.latitude,
          longitude: position.longitude,
          address: _address,
        ));
      }
    }
  }

  void _onCameraIdle() {
    _reverseGeocode(_selectedPosition);
  }

  void _onCameraMove(CameraPosition position) {
    _selectedPosition = position.target;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Map
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedPosition,
                  zoom: 15,
                ),
                onMapCreated: (controller) => _mapController = controller,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              // Center pin
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.location_pin,
                    size: 42,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              // Loading overlay
              if (_loadingLocation)
                Container(
                  color: Colors.white70,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              // My Location button
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'myLocation',
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Address display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: _loadingAddress
                    ? const Text('Obteniendo dirección...',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 13))
                    : Text(
                        _address,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Text(
          'Arrastra el mapa para ajustar la ubicación',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textTertiary,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
