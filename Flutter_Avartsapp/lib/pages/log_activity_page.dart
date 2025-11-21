import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:avarts/services/activity_service.dart';
import 'package:avarts/services/image_upload_service.dart';

class LogActivityPage extends StatefulWidget {
  const LogActivityPage({super.key, required this.currentUser});

  final String currentUser;

  @override
  State<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends State<LogActivityPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ActivityService _activityService = ActivityService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _activities = const [
    'Nap on Couch',
    'Bingewatching',
    'Netflix marathons',
    'Doomscrolling',
    'Snack break',
    'Meditation attempt',
    'Pro-level procrastination',
  ];

  String? _selectedActivity;
  int _hours = 1;
  int _minutes = 0;
  File? _selectedImageFile;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (_selectedActivity == null ||
        (_hours == 0 && _minutes == 0) ||
        title.isEmpty ||
        description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in activity, duration, title and story.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Calculate total minutes
      final totalMinutes = (_hours * 60) + _minutes;

      // Upload image if a file was selected
      String? imageUrl;
      if (_selectedImageFile != null) {
        try {
          imageUrl = await _imageUploadService.uploadToSupabaseStorage(
            file: _selectedImageFile!,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload image: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _submitting = false);
          return;
        }
      }

      // Post activity to Supabase
      await _activityService.postActivity(
        title: title,
        activity: _selectedActivity!,
        description: description,
        timeMinutes: totalMinutes,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      // Navigate back first, then show success message on the previous page
      // Use SchedulerBinding to avoid Navigator lock issues
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post activity: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickMedia() async {
    // Show options: Camera or Gallery
    final option = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop('gallery'),
              ),
            ],
          ),
        );
      },
    );

    if (option == null) return;

    // Handle camera or gallery
    try {
      final imageSource = option == 'camera'
          ? ImageSource.camera
          : ImageSource.gallery;
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Log activity')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(
            'Share your latest chill win',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedActivity,
            decoration: const InputDecoration(labelText: 'Choose activity'),
            items: _activities
                .map((text) => DropdownMenuItem(value: text, child: Text(text)))
                .toList(),
            onChanged: (value) => setState(() => _selectedActivity = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _hours,
                  decoration: const InputDecoration(labelText: 'Hours'),
                  items: List.generate(
                    13,
                    (i) => DropdownMenuItem(value: i, child: Text('$i')),
                  ),
                  onChanged: (value) =>
                      setState(() => _hours = value ?? _hours),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _minutes,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('00')),
                    DropdownMenuItem(value: 15, child: Text('15')),
                    DropdownMenuItem(value: 30, child: Text('30')),
                    DropdownMenuItem(value: 45, child: Text('45')),
                  ],
                  onChanged: (value) =>
                      setState(() => _minutes = value ?? _minutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Name your legendary chill session',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'How did it go?',
              hintText: 'Share the highlights of doing almost nothing',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _selectedImageFile == null
                        ? 'Upload media'
                        : 'Change media',
                  ),
                ),
              ),
              if (_selectedImageFile != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    _selectedImageFile!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _handleSubmit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_submitting ? 'Posting...' : 'Post activity'),
          ),
        ],
      ),
    );
  }
}
