import 'package:flutter/material.dart';
import 'package:flutter_avartsproto/models/activity_post.dart';

class LogActivityPage extends StatefulWidget {
  const LogActivityPage({super.key, required this.currentUser});

  final String currentUser;

  @override
  State<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends State<LogActivityPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _activities = const [
    'Nap on Couch',
    'Bingewatching classics',
    'Netflix marathons',
    'Doomscrolling cat videos',
    'Snack break',
    'Meditation attempt',
    'Pro-level procrastination',
  ];

  final List<String> _mediaOptions = const [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1500534319170-228a5339e7c3?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=800&q=80',
  ];

  String? _selectedActivity;
  int _hours = 1;
  int _minutes = 0;
  String? _selectedMedia;
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
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final post = ActivityPost(
      author: widget.currentUser,
      activity: _selectedActivity!,
      title: title,
      description: description,
      duration: Duration(hours: _hours, minutes: _minutes),
      createdAt: DateTime.now(),
      mediaUrl: _selectedMedia,
    );

    if (!mounted) return;
    Navigator.of(context).pop(post);
  }

  void _pickMedia() {
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _mediaOptions.length,
          itemBuilder: (context, index) {
            final url = _mediaOptions[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(url, fit: BoxFit.cover),
              ),
            );
          },
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() => _selectedMedia = value);
      }
    });
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
                    _selectedMedia == null ? 'Upload media' : 'Change media',
                  ),
                ),
              ),
              if (_selectedMedia != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    _selectedMedia!,
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
