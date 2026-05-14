import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';

class TournamentRegistrationForm extends StatefulWidget {
  const TournamentRegistrationForm({
    super.key,
    required this.category,
    required this.currentUser,
  });

  final CategoryModel category;
  final UserModel currentUser;

  @override
  State<TournamentRegistrationForm> createState() =>
      _TournamentRegistrationFormState();
}

class _TournamentRegistrationFormState
    extends State<TournamentRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<_RegistrationPlayerControllers> _players;
  var _showIdImageErrors = false;

  bool get _isDoubles =>
      widget.category.name.toLowerCase().contains('double');

  @override
  void initState() {
    super.initState();
    _players = [
      _RegistrationPlayerControllers(name: widget.currentUser.name),
      if (widget.category.name.toLowerCase().contains('double'))
        _RegistrationPlayerControllers(),
    ];
  }

  @override
  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  String? _ageValidator(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final age = int.tryParse(value!.trim());
    if (age == null || age < 1 || age > 120) return 'Enter a valid age';
    return null;
  }

  Map<String, dynamic> _details() {
    return {
      'type': _isDoubles ? 'doubles' : 'singles',
      'players': [
        for (var i = 0; i < _players.length; i++)
          {
            'slot': i + 1,
            'name': _players[i].name.text.trim(),
            'address': _players[i].address.text.trim(),
            'club': _players[i].club.text.trim(),
            'age': int.tryParse(_players[i].age.text.trim()) ?? 0,
            'idImage': _players[i].idImagePath,
            'contactNumber': _players[i].contactNumber.text.trim(),
          },
      ],
    };
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    final hasAllIdImages =
    _players.every((player) => player.idImagePath.isNotEmpty);
    setState(() => _showIdImageErrors = !hasAllIdImages);
    if (!ok || !hasAllIdImages) return;
    Navigator.pop(context, _details());
  }

  Future<void> _pickIdImage(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension = picked.name.split('.').last.toLowerCase();
    final mime = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : 'image/png';
    setState(() {
      _players[index].idImagePath =
      'data:$mime;base64,${base64Encode(bytes)}';
      _showIdImageErrors = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register for ${widget.category.name}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                _isDoubles
                    ? 'Enter details for both doubles players.'
                    : 'Enter your player details.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _players.length; i++) ...[
                _RegistrationPlayerSection(
                  title: _isDoubles ? 'Player ${i + 1}' : 'Player details',
                  controllers: _players[i],
                  requiredValidator: _required,
                  ageValidator: _ageValidator,
                  showIdImageError:
                  _showIdImageErrors && _players[i].idImagePath.isEmpty,
                  onPickIdImage: () => _pickIdImage(i),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Submit registration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationPlayerControllers {
  _RegistrationPlayerControllers({String name = ''})
      : name = TextEditingController(text: name),
        address = TextEditingController(),
        club = TextEditingController(),
        age = TextEditingController(),
        contactNumber = TextEditingController();

  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController club;
  final TextEditingController age;
  final TextEditingController contactNumber;
  String idImagePath = '';

  void dispose() {
    name.dispose();
    address.dispose();
    club.dispose();
    age.dispose();
    contactNumber.dispose();
  }
}

class _RegistrationPlayerSection extends StatelessWidget {
  const _RegistrationPlayerSection({
    required this.title,
    required this.controllers,
    required this.requiredValidator,
    required this.ageValidator,
    required this.showIdImageError,
    required this.onPickIdImage,
  });

  final String title;
  final _RegistrationPlayerControllers controllers;
  final FormFieldValidator<String> requiredValidator;
  final FormFieldValidator<String> ageValidator;
  final bool showIdImageError;
  final VoidCallback onPickIdImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controllers.name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: requiredValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            validator: requiredValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.club,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Club (optional)',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers.age,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: ageValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IdImagePicker(
                  imagePath: controllers.idImagePath,
                  showError: showIdImageError,
                  onPickImage: onPickIdImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.contactNumber,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Contact number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: requiredValidator,
          ),
        ],
      ),
    );
  }
}

class _IdImagePicker extends StatelessWidget {
  const _IdImagePicker({
    required this.imagePath,
    required this.showError,
    required this.onPickImage,
  });

  final String imagePath;
  final bool showError;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showError
                ? const Color(0xFFD32F2F)
                : const Color(0xFFDDE7D9),
            width: showError ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              imagePath.isEmpty ? Icons.badge_outlined : Icons.check_circle,
              color: imagePath.isEmpty
                  ? Colors.black54
                  : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                imagePath.isEmpty ? 'ID image' : 'ID attached',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: showError ? const Color(0xFFD32F2F) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}