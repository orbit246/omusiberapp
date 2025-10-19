import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationMode { manual, map }

class CreateEventData {
  final String title;
  final String description;
  final List<String> tags;
  final Uint8List? imageBytes;

  /// null == unlimited (∞)
  final int? maxContributors;

  /// Location: either manualAddress (if provided), or lat/lng (if picked on map)
  final String? manualAddress;
  final double? latitude;
  final double? longitude;

  const CreateEventData({
    required this.title,
    required this.description,
    required this.tags,
    required this.imageBytes,
    required this.maxContributors,
    required this.manualAddress,
    required this.latitude,
    required this.longitude,
  });
}

class CreateEventSheet extends StatefulWidget {
  const CreateEventSheet({super.key, required this.onCreate, required this.onFinishLater});

  final void Function(CreateEventData data) onCreate;
  final void Function(CreateEventData data) onFinishLater;

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _tags = <String>[];
  Uint8List? _imageBytes;
  bool _submitting = false;

  // Max contributors controls
  bool _unlimited = false;
  double _maxContribSlider = 10; // 1..100

  // Location controls
  LocationMode _locationMode = LocationMode.manual;

  LatLng _mapLatLng = const LatLng(41.0082, 28.9784); // Istanbul as a sensible default
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    _manualAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Take a photo', style: tt.bodyLarge),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery', style: tt.bodyLarge),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
    });
  }

  void _addTagFromField() {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_tags.contains(raw)) {
      setState(() => _tags.add(raw));
    }
    _tagCtrl.clear();
  }

  void _removeTag(String t) {
    setState(() => _tags.remove(t));
  }

  CreateEventData _collect() => CreateEventData(
    title: _titleCtrl.text.trim(),
    description: _descCtrl.text.trim(),
    tags: List.unmodifiable(_tags),
    imageBytes: _imageBytes,
    maxContributors: _unlimited ? null : _maxContribSlider.round(),
    manualAddress: _locationMode == LocationMode.manual ? _manualAddressCtrl.text.trim() : null,
    latitude: _locationMode == LocationMode.map ? _mapLatLng.latitude : null,
    longitude: _locationMode == LocationMode.map ? _mapLatLng.longitude : null,
  );

  Future<void> _submit(bool finishLater) async {
    if (!finishLater && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final data = _collect();

    try {
      if (finishLater) {
        widget.onFinishLater(data);
      } else {
        widget.onCreate(data);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    const inputRadius = 12.0; // slightly more rounded inputs
    const buttonRadius = 6.0; // less rounded buttons

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverList.list(
                  children: [
                    Text('Create Event', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      style: tt.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: tt.bodyMedium,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),

                    const SizedBox(height: 16),

                    // Image
                    Text('Image', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(inputRadius),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: _imageBytes == null ? 140 : 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(inputRadius),
                          color: cs.surfaceVariant.withOpacity(0.35),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: _imageBytes == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add, size: 32),
                                    const SizedBox(height: 8),
                                    Text('Add an image', style: tt.bodyMedium),
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(inputRadius),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(_imageBytes!, fit: BoxFit.cover),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(buttonRadius),
                                          ),
                                        ),
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.edit),
                                        label: Text('Change', style: tt.labelLarge),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 5,
                      minLines: 3,
                      style: tt.bodyLarge,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: tt.bodyMedium,
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tags
                    Text('Tags', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagCtrl,
                            textInputAction: TextInputAction.done,
                            style: tt.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Type a tag and press Enter',
                              hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius)),
                            ),
                            onSubmitted: (_) => _addTagFromField(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
                          ),
                          onPressed: _addTagFromField,
                          child: Text('Add', style: tt.labelLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _tags.isEmpty
                          ? Text('No tags yet', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tags
                                  .map(
                                    (t) => InputChip(
                                      label: Text(t, style: tt.bodyMedium),
                                      onDeleted: () => _removeTag(t),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // === Max Contributors ===
                    Text('Max contributors', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text('Limited', style: tt.labelLarge)),
                        ButtonSegment(value: true, label: Text('Unlimited', style: tt.labelLarge)),
                      ],
                      selected: {_unlimited},
                      onSelectionChanged: (sel) {
                        setState(() => _unlimited = sel.first);
                      },
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _unlimited ? 0.4 : 1.0,
                      child: IgnorePointer(
                        ignoring: _unlimited,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Selected: ', style: tt.bodyMedium),
                                Text(
                                  '${_maxContribSlider.round()}',
                                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Slider(
                              min: 1,
                              max: 100,
                              divisions: 99,
                              value: _maxContribSlider,
                              label: _maxContribSlider.round().toString(),
                              onChanged: (v) => setState(() => _maxContribSlider = v),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === Location ===
                    Text('Location', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<LocationMode>(
                      segments: [
                        ButtonSegment(
                          value: LocationMode.manual,
                          label: Text('Manual', style: tt.labelLarge),
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                        ButtonSegment(
                          value: LocationMode.map,
                          label: Text('Map', style: tt.labelLarge),
                          icon: const Icon(Icons.map_outlined),
                        ),
                      ],
                      selected: {_locationMode},
                      onSelectionChanged: (s) => setState(() => _locationMode = s.first),
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_locationMode == LocationMode.manual) ...[
                      TextFormField(
                        controller: _manualAddressCtrl,
                        style: tt.bodyLarge,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Address or place name',
                          hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius)),
                          prefixIcon: const Icon(Icons.place_outlined),
                        ),
                      ),
                    ] else ...[
                      // Inline Google Map with draggable marker
                      ClipRRect(
                        borderRadius: BorderRadius.circular(inputRadius),
                        child: SizedBox(
                          height: 220,
                          child: GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: CameraPosition(target: _mapLatLng, zoom: 14),
                            myLocationButtonEnabled: false,
                            myLocationEnabled: false,
                            onMapCreated: (c) => _mapController = c,
                            markers: {
                              Marker(
                                markerId: const MarkerId('pick'),
                                position: _mapLatLng,
                                draggable: true,
                                onDragEnd: (p) => setState(() => _mapLatLng = p),
                              ),
                            },
                            onTap: (p) => setState(() => _mapLatLng = p),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Lat: ${_mapLatLng.latitude.toStringAsFixed(5)} | Lng: ${_mapLatLng.longitude.toStringAsFixed(5)}',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
                            ),
                            onPressed: _submitting ? null : () => _submit(true),
                            child: Text('Finish later', style: tt.labelLarge),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
                            ),
                            onPressed: _submitting ? null : () => _submit(false),
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text('Create', style: tt.labelLarge),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
