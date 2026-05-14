import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/tournament_provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  final List<CategoryModel> _categories = [];

  // Default categories to make it easier for the user
  final List<String> _categoryOptions = [
    "Men's Singles",
    "Women's Singles",
    "Men's Doubles",
    "Women's Doubles",
    "Mixed Doubles"
  ];

  void _addCategory(String name) {
    setState(() {
      _categories.add(CategoryModel(
        name: name,
        slots: 16, // Default slots
        players: [],
        skillLevel: 'Open',
      ));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and add at least one category')),
      );
      return;
    }

    final provider = context.read<TournamentProvider>();
    final authService = AuthService();
    final currentUser = authService.getCurrentUser();

    if (currentUser == null) return;

    try {
      await provider.createTournament(
        name: _nameController.text,
        location: _locationController.text,
        date: _selectedDate,
        registrationStart: DateTime.now(),
        registrationEnd: _selectedDate.subtract(const Duration(days: 1)),
        creatorId: currentUser.id,
        categories: _categories,
      );

      await FirebaseAnalytics.instance.logEvent(
        name: 'tournament_created',
        parameters: {
          'creator_id': currentUser.id,
          'category_count': _categories.length,
          'location': _locationController.text.trim(),
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament created and pending approval!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
        backgroundColor: const Color(0xFF183A2E),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tournament Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location/Club Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Enter location' : null,
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text("Tournament Date"),
              subtitle: Text("${_selectedDate.toLocal()}".split(' ')[0]),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),

            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF183A2E)),
                  onSelected: _addCategory,
                  itemBuilder: (context) => _categoryOptions
                      .map((c) => PopupMenuItem<String>(
                    value: c,
                    child: Text(c),
                  ))
                      .toList(),
                ),
              ],
            ),

            if (_categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("No categories added yet.", style: TextStyle(color: Colors.grey))),
              ),

            ..._categories.asMap().entries.map((entry) {
              int idx = entry.key;
              CategoryModel cat = entry.value;
              return Card(
                child: ListTile(
                  title: Text(cat.name),
                  subtitle: Text("Slots: ${cat.slots}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _categories.removeAt(idx)),
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF183A2E),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Submit for Approval', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}