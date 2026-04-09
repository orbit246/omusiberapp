import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
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

class CreateEventSheet extends StatelessWidget {
  const CreateEventSheet({super.key, this.onCreate, this.onFinishLater});

  final void Function(CreateEventData data)? onCreate;
  final void Function(CreateEventData data)? onFinishLater;

  @override
  Widget build(BuildContext context) {
    return CreateEventPage(onCreate: onCreate, onFinishLater: onFinishLater);
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key, this.onCreate, this.onFinishLater});

  final void Function(CreateEventData data)? onCreate;
  final void Function(CreateEventData data)? onFinishLater;

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  final _mapController = MapController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _tags = <String>[];
  final List<Uint8List> _images = [];
  bool _submitting = false;
  String? _loadingStatus;

  bool _unlimited = false;
  double _maxContribSlider = 10;
  LocationMode _locationMode = LocationMode.manual;
  LatLng _mapLatLng = const LatLng(41.2867, 36.3300);

  @override
  void initState() {
    super.initState();
    final rounded = _roundedUpDateTime(
      DateTime.now().add(const Duration(minutes: 30)),
    );
    _selectedDate = DateUtils.dateOnly(rounded);
    _selectedTime = TimeOfDay(hour: rounded.hour, minute: rounded.minute);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    _manualAddressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  DateTime _roundedUpDateTime(DateTime value) {
    final roundedMinute = ((value.minute + 14) ~/ 15) * 15;
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      roundedMinute,
    );
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  DateTime get _tomorrow => _today.add(const Duration(days: 1));

  DateTime get _nextWeekend {
    final base = _today;
    final daysUntilSaturday = (DateTime.saturday - base.weekday + 7) % 7;
    return base.add(
      Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday),
    );
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
        if (!mounted) return;
        setState(() => _images.add(bytes));
      }
      return;
    }

    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _images.add(bytes));
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
    if (!_tags.contains(raw)) {
      setState(() => _tags.add(raw));
    }
    _tagCtrl.clear();
  }

  void _removeTag(String t) {
    setState(() => _tags.remove(t));
  }

  void _selectDate(DateTime value) {
    setState(() => _selectedDate = DateUtils.dateOnly(value));
  }

  void _updateTime({int? hour, int? minute}) {
    final current = _selectedTime ?? const TimeOfDay(hour: 12, minute: 0);
    setState(() {
      _selectedTime = TimeOfDay(
        hour: hour ?? current.hour,
        minute: minute ?? current.minute,
      );
    });
  }

  DateTime? _combinedDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  CreateEventData? _collectData() {
    final dateTime = _combinedDateTime();
    if (dateTime == null) return null;

    return CreateEventData(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      eventDateTime: dateTime,
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

  Future<void> _handleSecondaryAction() async {
    if (widget.onFinishLater == null) {
      Navigator.of(context).maybePop();
      return;
    }

    final data = _collectData();
    if (data == null) return;
    widget.onFinishLater?.call(data);
    if (!mounted) return;
    Navigator.of(context).pop(data);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = _collectData();
    final eventDateTime = data?.eventDateTime;
    if (data == null || eventDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tarih ve saat seçiniz.')),
      );
      return;
    }

    if (eventDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik zamanı gelecekte olmalıdır.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _loadingStatus = 'Hazırlanıyor...';
    });

    try {
      final uploader = ImageKitUploader(
        urlEndpoint: 'https://ik.imagekit.io/forgelabs/',
      );

      final uploadedImageLinks = <String>[];
      String thumbnail = '';

      for (int i = 0; i < _images.length; i++) {
        final imgBytes = _images[i];
        setState(() {
          _loadingStatus =
              'Görseller yükleniyor (${i + 1}/${_images.length})...';
        });

        final fileName =
            'event_img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        try {
          final result = await uploader.uploadBytes(
            bytes: imgBytes,
            fileName: fileName,
            folder: '/events',
          );
          uploadedImageLinks.add(result.url);
        } catch (e) {
          debugPrint('Image upload failed: $e');
        }
      }

      if (uploadedImageLinks.isNotEmpty) {
        thumbnail = uploadedImageLinks.first;
      }

      setState(() => _loadingStatus = 'Etkinlik kaydediliyor...');

      final eventRepo = EventRepository();
      final locationStr = data.manualAddress?.trim().isNotEmpty == true
          ? data.manualAddress!.trim()
          : (data.latitude != null && data.longitude != null)
          ? '${data.latitude}, ${data.longitude}'
          : 'Konum Belirtilmedi';

      final postView = PostView(
        id: 'pending-create',
        title: data.title,
        description: data.description,
        tags: data.tags,
        maxContributors: data.maxContributors ?? 0,
        remainingContributors: data.maxContributors ?? 0,
        ticketPrice: 0,
        location: locationStr,
        thubnailUrl: thumbnail,
        imageLinks: uploadedImageLinks,
        metadata: {
          'createdAt': DateTime.now().toIso8601String(),
          'eventDate': data.eventDateTime.toIso8601String(),
          if (data.latitude != null) 'latitude': data.latitude!,
          if (data.longitude != null) 'longitude': data.longitude!,
        },
      );

      await eventRepo.addEvent(postView);

      widget.onCreate?.call(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatSelectedDateTime() {
    final dt = _combinedDateTime();
    if (dt == null) return 'Tarih ve saat seçiniz';
    return DateFormat('d MMMM yyyy, EEEE • HH:mm', 'tr').format(dt);
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer, cs.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Yeni etkinlik akışı',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Etkinliğini rahatça planla, tarihi takvimden seç ve tek sayfada yayınla.',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Artık tarih seçimi için sıkışık bir popup yerine geniş bir oluşturma sayfası var. Takvim, saat ve konum aynı akışta düzenlenebiliyor.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryPill(
                context,
                icon: Icons.event_available,
                label: _formatSelectedDateTime(),
              ),
              _buildSummaryPill(
                context,
                icon: Icons.groups_2_outlined,
                label: _unlimited
                    ? 'Sınırsız katılım'
                    : '${_maxContribSlider.round()} kişilik limit',
              ),
              _buildSummaryPill(
                context,
                icon: Icons.photo_library_outlined,
                label: _images.isEmpty
                    ? 'Kapak görseli eklenmedi'
                    : '${_images.length} görsel hazır',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedDate = _selectedDate ?? _today;
    final selectedTime = _selectedTime ?? const TimeOfDay(hour: 12, minute: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatSelectedDateTime(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Bugün'),
              selected: _isSameDay(selectedDate, _today),
              onSelected: (_) => _selectDate(_today),
            ),
            ChoiceChip(
              label: const Text('Yarın'),
              selected: _isSameDay(selectedDate, _tomorrow),
              onSelected: (_) => _selectDate(_tomorrow),
            ),
            ChoiceChip(
              label: const Text('Hafta Sonu'),
              selected: _isSameDay(selectedDate, _nextWeekend),
              onSelected: (_) => _selectDate(_nextWeekend),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: _today,
            lastDate: _today.add(const Duration(days: 365)),
            onDateChanged: _selectDate,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final fields = [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedTime.hour,
                  decoration: const InputDecoration(
                    labelText: 'Saat',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  items: List.generate(
                    24,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) _updateTime(hour: value);
                  },
                ),
              ),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedTime.minute,
                  decoration: const InputDecoration(
                    labelText: 'Dakika',
                    prefixIcon: Icon(Icons.timelapse_outlined),
                  ),
                  items: List.generate(12, (index) => index * 5)
                      .map(
                        (minute) => DropdownMenuItem(
                          value: minute,
                          child: Text(minute.toString().padLeft(2, '0')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _updateTime(minute: value);
                  },
                ),
              ),
            ];

            if (isCompact) {
              return Column(
                children: [fields[0], const SizedBox(height: 12), fields[1]],
              );
            }

            return Row(
              children: [fields[0], const SizedBox(width: 12), fields[1]],
            );
          },
        ),
      ],
    );
  }

  Widget _buildImagesSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 44,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kapak görseli ekle',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'İlk görsel etkinlik kartında kapak olarak kullanılacak.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Kapak',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              onReorder: _onReorderImages,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey(_images[index]),
                  width: 92,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: index == 0 ? cs.primary : cs.outlineVariant,
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
                          top: 6,
                          left: 6,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: cs.primary,
                            child: const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeImage(index),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.55,
                            ),
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
          const SizedBox(height: 8),
          Text(
            'Sıralamayı değiştirmek için basılı tutup sürükleyin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Etkinlik Oluştur'),
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _handleSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        widget.onFinishLater == null
                            ? 'İptal'
                            : 'Taslağı Kaydet',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('Etkinliği Yayınla'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.surface,
                    cs.primaryContainer.withValues(alpha: 0.16),
                    cs.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                        sliver: SliverList.list(
                          children: [
                            _buildHero(context),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.photo_library_outlined,
                              title: 'Poster ve Galeri',
                              subtitle:
                                  'Kapak görselini belirle, ek fotoğrafları sırala.',
                              child: _buildImagesSection(context),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.edit_note_outlined,
                              title: 'Temel Bilgiler',
                              subtitle:
                                  'Etkinlik başlığı ve açıklamasını net şekilde yaz.',
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _titleCtrl,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Etkinlik Başlığı',
                                      hintText: 'Örn: Girişimcilik Atölyesi',
                                      prefixIcon: const Icon(Icons.title),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Başlık zorunludur';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _descCtrl,
                                    minLines: 4,
                                    maxLines: 7,
                                    decoration: InputDecoration(
                                      labelText: 'Açıklama',
                                      hintText:
                                          'Katılımcıları neyin beklediğini anlat.',
                                      alignLabelWithHint: true,
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 72),
                                        child: Icon(Icons.description_outlined),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.calendar_month_outlined,
                              title: 'Tarih ve Saat',
                              subtitle:
                                  'Takvimden gününü seç, saati tek bakışta ayarla.',
                              child: _buildDateSection(context),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.sell_outlined,
                              title: 'Etiketler',
                              subtitle:
                                  'Etkinliği aramada öne çıkarmak için kısa etiketler ekle.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _tagCtrl,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Etiket yaz ve Enter’a bas',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          onSubmitted: (_) =>
                                              _addTagFromField(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton.filledTonal(
                                        onPressed: _addTagFromField,
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_tags.isEmpty)
                                    Text(
                                      'Henüz etiket eklenmedi.',
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _tags
                                          .map(
                                            (tag) => InputChip(
                                              label: Text(tag),
                                              onDeleted: () => _removeTag(tag),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.groups_outlined,
                              title: 'Katılımcı Limiti',
                              subtitle:
                                  'İstersen kapasite belirle, istersen açık bırak.',
                              child: Column(
                                children: [
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
                                    onSelectionChanged: (selection) {
                                      setState(
                                        () => _unlimited = selection.first,
                                      );
                                    },
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
                                            onChanged: (value) {
                                              setState(
                                                () => _maxContribSlider = value,
                                              );
                                            },
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Text(
                                            '${_maxContribSlider.round()}',
                                            style: tt.titleMedium?.copyWith(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              context: context,
                              icon: Icons.place_outlined,
                              title: 'Konum',
                              subtitle:
                                  'Mekanı manuel gir veya harita üzerinden işaretle.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<LocationMode>(
                                      segments: const [
                                        ButtonSegment(
                                          value: LocationMode.manual,
                                          label: Text('Adres Gir'),
                                          icon: Icon(
                                            Icons.edit_location_alt_outlined,
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: LocationMode.map,
                                          label: Text('Haritadan Seç'),
                                          icon: Icon(Icons.map_outlined),
                                        ),
                                      ],
                                      selected: {_locationMode},
                                      onSelectionChanged: (selection) {
                                        setState(
                                          () => _locationMode = selection.first,
                                        );
                                      },
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
                                            18,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          child: Container(
                                            height: 280,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: cs.outlineVariant
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: FlutterMap(
                                              mapController: _mapController,
                                              options: MapOptions(
                                                initialCenter: _mapLatLng,
                                                initialZoom: 13,
                                                onTap: (_, point) {
                                                  setState(
                                                    () => _mapLatLng = point,
                                                  );
                                                },
                                              ),
                                              children: [
                                                TileLayer(
                                                  urlTemplate:
                                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Seçili konum: ${_mapLatLng.latitude.toStringAsFixed(4)}, ${_mapLatLng.longitude.toStringAsFixed(4)}',
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.42),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _loadingStatus ?? 'İşleniyor...',
                          textAlign: TextAlign.center,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
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
            ),
        ],
      ),
    );
  }
}
