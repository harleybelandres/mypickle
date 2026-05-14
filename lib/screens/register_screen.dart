import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool obscure = true;
  bool isLoading = false;
  String selectedRole = 'player';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.trim().isEmpty) return 'Password is required';
    if (v.trim().length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit(BuildContext context) async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => isLoading = true);
    try {
      await AuthService().signUp(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passController.text,
        role: selectedRole,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please login.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AnimatedIn(
                child: _AuthHeader(
                  title: 'Start playing',
                  message:
                      'Create your account to join tournaments and track progress.',
                  icon: Icons.person_add_alt_1,
                ),
              ),
              const SizedBox(height: 16),
              _AnimatedIn(
                delay: 110,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: 'Name',
                            ),
                            validator: _validateName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined),
                              labelText: 'Email',
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passController,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                tooltip: obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    key: ValueKey(obscure),
                                  ),
                                ),
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                              ),
                            ),
                            validator: _validatePassword,
                            onFieldSubmitted: (_) => _submit(context),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'player',
                                icon: Icon(Icons.sports_tennis_outlined),
                                label: Text('Player'),
                              ),
                              ButtonSegment(
                                value: 'umpire',
                                icon: Icon(Icons.sports_outlined),
                                label: Text('Umpire'),
                              ),
                            ],
                            selected: {selectedRole},
                            onSelectionChanged: (selection) {
                              setState(() => selectedRole = selection.first);
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _submit(context),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: isLoading
                                    ? const SizedBox(
                                        key: ValueKey('loading'),
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Create account',
                                        key: ValueKey('label'),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Already have an account? Login'),
                          ),
                        ],
                      ),
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

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF183A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
