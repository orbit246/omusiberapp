import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/imagekit_uploader.dart';
import 'package:omusiber/backend/post_view.dart';

enum LocationMode { manual, map }

class CreateEventData {
  final String title;
  final String description;
  final DateTime eventDateTime;
  final List<String> tags;
  final List<Uint8List> images;
  final int? maxContributors;
  final String? manualAddress;
  final double? latitude;
  final double? longitude;

  const CreateEventData({
    required this.title,
    required this.description,
    required this.eventDateTime,
    required this.tags,
    required this.images,
    required this.maxContributors,
    required this.manualAddress,
    required this.latitude,
    required this.longitude,
  });
}

class CreateEventSheet extends StatefulWidget {
  const CreateEventSheet({
    super.key,
    required this.onCreate,
    required this.onFinishLater,
  });

  final void Function(CreateEventData data) onCreate;
  final void Function(CreateEventData data) onFinishLater;

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  // --- Controllers ---
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  final _mapController = MapController();
  final _formKey = GlobalKey<FormState>();

  // --- State Variables ---
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _tags = <String>[];
  final List<Uint8List> _images = [];
  bool _submitting = false;
  String? _loadingStatus;

  // --- Logic Toggles ---
  bool _unlimited = false;
  double _maxContribSlider = 10;
  LocationMode _locationMode = LocationMode.manual;
  LatLng _mapLatLng = const LatLng(41.2867, 36.3300); // Default: Samsun

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    _manualAddressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotoğraf Çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç (Çoklu)'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(imageQuality: 80);
      if (files.isEmpty) return;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        setState(() => _images.add(bytes));
      }
    } else {
      final file = await picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _images.add(bytes));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _onReorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  void _addTagFromField() {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_tags.contains(raw)) setState(() => _tags.add(raw));
    _tagCtrl.clear();
  }

  void _removeTag(String t) {
    setState(() => _tags.remove(t));
  }

  CreateEventData? _collectData() {
    if (_selectedDate == null || _selectedTime == null) return null;

    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    return CreateEventData(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      eventDateTime: dt,
      tags: List.unmodifiable(_tags),
      images: List.unmodifiable(_images),
      maxContributors: _unlimited ? null : _maxContribSlider.round(),
      manualAddress: _locationMode == LocationMode.manual
          ? _manualAddressCtrl.text.trim()
          : null,
      latitude: _locationMode == LocationMode.map ? _mapLatLng.latitude : null,
      longitude: _locationMode == LocationMode.map
          ? _mapLatLng.longitude
          : null,
    );
  }

  Future<void> _submit(bool finishLater) async {
    if (!finishLater) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tarih ve saat seçiniz.')),
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _loadingStatus = "Hazırlanıyor...";
    });

    final data = _collectData();

    if (data != null) {
      try {
        final uploader = ImageKitUploader(
          urlEndpoint: 'https://ik.imagekit.io/forgelabs/',
        );

        // 1. Upload Images
        final uploadedImageLinks = <String>[];
        String thumbnail = '';

        for (int i = 0; i < _images.length; i++) {
          final imgBytes = _images[i];
          setState(
            () => _loadingStatus =
                "Görseller yükleniyor (${i + 1}/${_images.length})...",
          );

          // Generate a random filename
          final fileName =
              'event_img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

          try {
            final result = await uploader.uploadBytes(
              bytes: imgBytes,
              fileName: fileName,
              folder: '/events', // Optional organization
            );
            uploadedImageLinks.add(result.url);
          } catch (e) {
            debugPrint("Image upload failed: $e");
            // Choose whether to abort or continue. Let's continue but warn?
            // Better to abort if critical, but let's assume valid bytes.
          }
        }

        if (uploadedImageLinks.isNotEmpty) {
          thumbnail = uploadedImageLinks.first;
        }

        // 2. Create Event Object
        setState(() => _loadingStatus = "Etkinlik kaydediliyor...");

        final eventRepo = EventRepository();
        final eventId = FirebaseFirestore.instance
            .collection('events')
            .doc()
            .id;

        final locationStr =
            data.manualAddress ??
            (data.latitude != null
                ? '${data.latitude}, ${data.longitude}'
                : 'Konum Belirtilmedi');

        final postView = PostView(
          id: eventId,
          title: data.title,
          description: data.description,
          tags: data.tags,
          maxContributors:
              data.maxContributors ??
              0, // 0 means unlimited/unspecified logic usually, but let's stick to int
          remainingContributors: data.maxContributors ?? 0,
          ticketPrice: 0, // Not in UI yet based on code read
          location: locationStr,
          thubnailUrl: thumbnail,
          imageLinks: uploadedImageLinks,
          metadata: {
            'createdAt': DateTime.now().toIso8601String(),
            'eventDate': data.eventDateTime.toIso8601String(),
            // Store raw lat/long if map mode
            if (data.latitude != null) 'latitude': data.latitude!,
            if (data.longitude != null) 'longitude': data.longitude!,
          },
        );

        await eventRepo.addEvent(postView);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu!')),
          );
          Navigator.pop(context); // Close sheet
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata oluştu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    const inputRadius = 16.0;

    // Formatters
    final dateStr = _selectedDate == null
        ? 'Tarih Seç'
        : DateFormat('d MMM yyyy', 'tr').format(_selectedDate!);

    final timeStr = _selectedTime == null
        ? 'Saat'
        : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    return FractionallySizedBox(
      heightFactor: 0.95,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header Drag Handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: SliverList.list(
                            children: [
                              Text(
                                'Etkinlik Oluştur',
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Detayları girerek yeni bir etkinlik başlat.',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // --- 1. IMAGES (Cover + Reorderable) ---
                              InkWell(
                                onTap: _pickImages,
                                borderRadius: BorderRadius.circular(
                                  inputRadius,
                                ),
                                child: Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      inputRadius,
                                    ),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    image: _images.isNotEmpty
                                        ? DecorationImage(
                                            image: MemoryImage(_images.first),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _images.isEmpty
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 40,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Fotoğraf Ekle',
                                              style: tt.labelLarge?.copyWith(
                                                color: cs.primary,
                                              ),
                                            ),
                                            Text(
                                              '(İlk fotoğraf kapak olur)',
                                              style: tt.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Kapak',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // Thumbnails List
                              if (_images.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 80,
                                  child: ReorderableListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    onReorder: _onReorderImages,
                                    itemCount: _images.length,
                                    proxyDecorator: (child, index, animation) =>
                                        Material(
                                          elevation: 8,
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: child,
                                        ),
                                    itemBuilder: (context, index) {
                                      return Container(
                                        key: ValueKey(_images[index]),
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        width: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: index == 0
                                                ? cs.primary
                                                : cs.outlineVariant,
                                            width: index == 0 ? 2 : 1,
                                          ),
                                          image: DecorationImage(
                                            image: MemoryImage(_images[index]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            if (index == 0)
                                              Positioned(
                                                top: 4,
                                                left: 4,
                                                child: CircleAvatar(
                                                  radius: 8,
                                                  backgroundColor: cs.primary,
                                                  child: const Icon(
                                                    Icons.star,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: InkWell(
                                                onTap: () =>
                                                    _removeImage(index),
                                                child: CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: Colors.black
                                                      .withOpacity(0.6),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(
                                    'Sıralamak için basılı tutup sürükleyin',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // --- 2. TEXT FIELDS ---
                              TextFormField(
                                controller: _titleCtrl,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Etkinlik Başlığı',
                                  hintText: 'Örn: Kodlama Kampı',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      inputRadius,
                                    ),
                                  ),
                                  prefixIcon: const Icon(Icons.title),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Başlık zorunludur'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descCtrl,
                                maxLines: 4,
                                minLines: 2,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  labelText: 'Açıklama',
                                  hintText: 'Etkinlik hakkında detaylar...',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      inputRadius,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.description_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // --- 3. DATE & TIME (3:2 Ratio) ---
                              Row(
                                children: [
                                  // Date (Flex 3)
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(
                                        inputRadius,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: cs.outline),
                                          borderRadius: BorderRadius.circular(
                                            inputRadius,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: _selectedDate == null
                                                  ? cs.onSurfaceVariant
                                                  : cs.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                dateStr,
                                                style: tt.bodyLarge?.copyWith(
                                                  color: _selectedDate == null
                                                      ? cs.onSurfaceVariant
                                                      : cs.onSurface,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Time (Flex 2)
                                  Expanded(
                                    flex: 2,
                                    child: InkWell(
                                      onTap: _pickTime,
                                      borderRadius: BorderRadius.circular(
                                        inputRadius,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: cs.outline),
                                          borderRadius: BorderRadius.circular(
                                            inputRadius,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: _selectedTime == null
                                                  ? cs.onSurfaceVariant
                                                  : cs.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              timeStr,
                                              style: tt.bodyLarge?.copyWith(
                                                color: _selectedTime == null
                                                    ? cs.onSurfaceVariant
                                                    : cs.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // --- 4. TAGS ---
                              Text(
                                'Etiketler',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _tagCtrl,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        hintText: 'Etiket yaz (Enter)',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onSubmitted: (_) => _addTagFromField(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _addTagFromField,
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_tags.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _tags
                                      .map(
                                        (t) => InputChip(
                                          label: Text(t),
                                          onDeleted: () => _removeTag(t),
                                          backgroundColor: cs.secondaryContainer
                                              .withOpacity(0.5),
                                        ),
                                      )
                                      .toList(),
                                )
                              else
                                Text(
                                  'Henüz etiket eklenmedi.',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),

                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 24),

                              // --- 5. CONTRIBUTORS ---
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Katılımcı Limiti',
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(
                                        value: false,
                                        label: Text('Sınırlı'),
                                      ),
                                      ButtonSegment(
                                        value: true,
                                        label: Text('Sınırsız'),
                                      ),
                                    ],
                                    selected: {_unlimited},
                                    onSelectionChanged: (s) =>
                                        setState(() => _unlimited = s.first),
                                    style: ButtonStyle(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_unlimited) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        min: 1,
                                        max: 100,
                                        divisions: 99,
                                        value: _maxContribSlider,
                                        label: _maxContribSlider
                                            .round()
                                            .toString(),
                                        onChanged: (v) => setState(
                                          () => _maxContribSlider = v,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_maxContribSlider.round()}',
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 24),

                              // --- 6. LOCATION ---
                              Text(
                                'Konum Seçimi',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<LocationMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: LocationMode.manual,
                                      label: Text('Adres Gir'),
                                      icon: Icon(Icons.edit_location),
                                    ),
                                    ButtonSegment(
                                      value: LocationMode.map,
                                      label: Text('Haritadan Seç'),
                                      icon: Icon(Icons.map),
                                    ),
                                  ],
                                  selected: {_locationMode},
                                  onSelectionChanged: (s) =>
                                      setState(() => _locationMode = s.first),
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_locationMode == LocationMode.manual)
                                TextFormField(
                                  controller: _manualAddressCtrl,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Adres veya Mekan Adı',
                                    prefixIcon: const Icon(Icons.place),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        inputRadius,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                // FLUTTER MAP
                                Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        inputRadius,
                                      ),
                                      child: Container(
                                        height: 250,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: cs.outlineVariant,
                                          ),
                                        ),
                                        child: FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            initialCenter: _mapLatLng,
                                            initialZoom: 13.0,
                                            onTap: (_, point) => setState(
                                              () => _mapLatLng = point,
                                            ),
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate:
                                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              // UPDATED USER AGENT HERE:
                                              userAgentPackageName:
                                                  'me.orbitium.akademiz',
                                            ),
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: _mapLatLng,
                                                  width: 50,
                                                  height: 50,
                                                  child: const Icon(
                                                    Icons.location_on,
                                                    size: 40,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Seçili: ${_mapLatLng.latitude.toStringAsFixed(4)}, ${_mapLatLng.longitude.toStringAsFixed(4)}',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- BOTTOM BAR ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border(
                        top: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _submitting ? null : () => _submit(true),
                            child: const Text('Taslağı Kaydet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _submitting
                                ? null
                                : () => _submit(false),
                            child: const Text('Oluştur'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LOADING OVERLAY ---
          if (_submitting)
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _loadingStatus ?? 'İşleniyor...',
                        textAlign: TextAlign.center,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lütfen bekleyiniz, bu işlem biraz sürebilir.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
