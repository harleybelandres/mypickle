import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/category_model.dart';
import '../providers/tournament_provider.dart';
import '../services/auth_service.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  static const skillLevels = [
    'Beginners',
    'Novice - Lower',
    'Novice - Upper',
    'Intermediate - Lower',
    'Intermediate - Upper',
    'Advanced',
    'Open Age',
  ];

  static const eventCategories = [
    'Men Singles',
    'Women Singles',
    'Men Doubles',
    'Women Doubles',
    'Mixed Doubles',
    'MLP',
  ];

  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final slotsController = TextEditingController(text: '16');
  final formKey = GlobalKey<FormState>();

  DateTime selectedDate = DateTime.now();
  DateTime registrationStart = DateTime.now();
  DateTime registrationEnd = DateTime.now().add(const Duration(days: 7));
  bool isLoading = false;
  String tournamentImagePath = '';
  String selectedSkillLevel = skillLevels.first;
  String selectedEventCategory = eventCategories.first;
  final List<CategoryModel> categories = [
    const CategoryModel(
      name: 'Men Singles - Beginners',
      skillLevel: 'Beginners',
      slots: 16,
      players: [],
    ),
  ];

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    slotsController.dispose();
    super.dispose();
  }

  String _dateText() =>
      '${selectedDate.toLocal().year}-${selectedDate.toLocal().month.toString().padLeft(2, '0')}-${selectedDate.toLocal().day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) =>
      '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}';

  Future<void> _pickTournamentImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.split('.').last.toLowerCase();
    final mime = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : 'image/png';
    setState(() {
      tournamentImagePath = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  void _addCategory() {
    final name = '$selectedEventCategory - $selectedSkillLevel';
    final skill = selectedSkillLevel;
    final slots = int.tryParse(slotsController.text.trim()) ?? 0;

    if (slots < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least 2 slots for this category.'),
        ),
      );
      return;
    }

    final exists = categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That category already exists.')),
      );
      return;
    }

    setState(() {
      categories.add(
        CategoryModel(
          name: name,
          skillLevel: skill,
          slots: slots,
          players: const [],
        ),
      );
      slotsController.text = '16';
    });
  }

  Future<void> _submit() async {
    final ok = formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one category.')),
      );
      return;
    }
    if (registrationEnd.isBefore(registrationStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration end must be after registration start.'),
        ),
      );
      return;
    }
    if (registrationEnd.isAfter(selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration must close on or before tournament date.',
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final currentUser = AuthService().getCurrentUser();
      if (currentUser == null) {
        throw Exception('You must be logged in to create a tournament');
      }

      await Provider.of<TournamentProvider>(
        context,
        listen: false,
      ).createTournament(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        date: selectedDate,
        registrationStart: registrationStart,
        registrationEnd: registrationEnd,
        creatorId: currentUser.id,
        imagePath: tournamentImagePath,
        categories: List<CategoryModel>.from(categories),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament created for admin approval.')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: isLoading
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const SizedBox(key: ValueKey('idle'), width: 8),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedIn(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF183A2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournament setup',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create the event, define categories, then submit for admin approval.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AnimatedIn(
                delay: 80,
                child: _Surface(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.sports_tennis_outlined),
                            labelText: 'Tournament name',
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) {
                              return 'Please enter a tournament name';
                            }
                            if (s.length < 3) return 'Name is too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.place_outlined),
                            labelText: 'Location',
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Please enter a location';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _TournamentImagePicker(
                          imagePath: tournamentImagePath,
                          onPickImage: _pickTournamentImage,
                        ),
                        const SizedBox(height: 12),
                        _DateButton(
                          label: _dateText(),
                          title: 'Tournament date',
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                                if (registrationEnd.isAfter(selectedDate)) {
                                  registrationEnd = selectedDate;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DateButton(
                                title: 'Registration start',
                                label: _formatDate(registrationStart),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: registrationStart,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      registrationStart = picked;
                                      if (registrationEnd.isBefore(
                                        registrationStart,
                                      )) {
                                        registrationEnd = registrationStart;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DateButton(
                                title: 'Registration end',
                                label: _formatDate(registrationEnd),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: registrationEnd,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => registrationEnd = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AnimatedIn(
                delay: 140,
                child: _SectionTitle(
                  title: 'Categories',
                  count: categories.length,
                ),
              ),
              const SizedBox(height: 10),
              _AnimatedIn(
                delay: 180,
                child: _Surface(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedEventCategory,
                              decoration: const InputDecoration(
                                labelText: 'Event category',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: eventCategories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => selectedEventCategory = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 112,
                            child: TextField(
                              controller: slotsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Slots',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSkillLevel,
                              decoration: const InputDecoration(
                                labelText: 'Skill level',
                                prefixIcon: Icon(Icons.speed_outlined),
                              ),
                              items: skillLevels
                                  .map(
                                    (skill) => DropdownMenuItem(
                                      value: skill,
                                      child: Text(skill),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => selectedSkillLevel = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _addCategory,
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: categories.isEmpty
                            ? const Text(
                                'No categories added yet.',
                                key: ValueKey('empty-categories'),
                                style: TextStyle(color: Colors.black54),
                              )
                            : Column(
                                key: ValueKey(categories.length),
                                children: [
                                  for (final category in categories)
                                    _CategoryChip(
                                      category: category,
                                      onDelete: categories.length == 1
                                          ? null
                                          : () {
                                              setState(
                                                () =>
                                                    categories.remove(category),
                                              );
                                            },
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _AnimatedIn(
                delay: 240,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    onPressed: isLoading ? null : _submit,
                    label: Text(
                      isLoading ? 'Submitting...' : 'Submit for approval',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentImagePicker extends StatelessWidget {
  const _TournamentImagePicker({
    required this.imagePath,
    required this.onPickImage,
  });

  final String imagePath;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 82,
              height: 58,
              child: imagePath.isEmpty
                  ? Container(
                      color: const Color(0xFF183A2E),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                      ),
                    )
                  : Image.memory(
                      base64Decode(imagePath.split(',').last),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tournament image is optional. If empty, the system uses an automatic cover.',
              style: TextStyle(color: Colors.black54, height: 1.25),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Choose image',
            onPressed: onPickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.title,
    required this.label,
    required this.onTap,
  });

  final String title;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onDelete});

  final CategoryModel category;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${category.skillLevel} - ${category.slots} slots',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove category',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '$count added',
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: child,
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayed = delay == 0 ? value : (value * 1.18 - 0.18).clamp(0, 1);
        return Opacity(
          opacity: delayed.toDouble(),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - delayed.toDouble())),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
