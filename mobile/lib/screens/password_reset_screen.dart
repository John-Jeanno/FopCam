import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    this.initialChannel = 'email',
    this.initialIdentifier = '',
  });

  final String initialChannel;
  final String initialIdentifier;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _channel = 'email';
  bool _codeRequested = false;
  bool _isLoading = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
    _identifierController.text = widget.initialIdentifier;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_identifierController.text.trim().isEmpty) {
      setState(() => _error = 'Saisissez votre email ou votre numéro.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await ApiService.requestPasswordReset(
        channel: _channel,
        identifier: _identifierController.text,
      );
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _message =
            'Si un compte correspond, un code a été envoyé. '
            'Vérifiez aussi vos courriers indésirables.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await ApiService.confirmPasswordReset(
        channel: _channel,
        identifier: _identifierController.text,
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF991B1B);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Récupérer mon compte'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                size: 56,
                color: Color(0xFFFCA5A5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Réinitialiser le mot de passe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recevez un code temporaire sur l’adresse email ou le numéro '
                'WhatsApp associé à votre compte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFBFC6D4), height: 1.5),
              ),
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF111827),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'email',
                            icon: Icon(Icons.email_outlined),
                            label: Text('Email'),
                          ),
                          ButtonSegment(
                            value: 'whatsapp',
                            icon: Icon(Icons.chat_outlined),
                            label: Text('WhatsApp'),
                          ),
                        ],
                        selected: {_channel},
                        onSelectionChanged: _codeRequested
                            ? null
                            : (selection) =>
                                  setState(() => _channel = selection.first),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _identifierController,
                        enabled: !_codeRequested,
                        keyboardType: _channel == 'email'
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _channel == 'email'
                              ? 'Adresse email du compte'
                              : 'Téléphone avec indicatif pays',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          hintText: _channel == 'email'
                              ? 'nom@exemple.com'
                              : '+221 77 000 00 00',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(
                            _channel == 'email'
                                ? Icons.email_outlined
                                : Icons.phone_iphone,
                            color: const Color(0xFF94A3B8),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_codeRequested) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Code reçu',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(
                              Icons.password,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            helperText: 'Au moins 8 caractères',
                            helperStyle: TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _message!,
                          style: const TextStyle(color: Color(0xFF86EFAC)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : _codeRequested
                            ? _confirmReset
                            : _requestCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _isLoading
                              ? 'Veuillez patienter...'
                              : _codeRequested
                              ? 'Changer le mot de passe'
                              : 'Envoyer le code',
                        ),
                      ),
                      if (_codeRequested)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                  _codeRequested = false;
                                  _message = null;
                                  _codeController.clear();
                                }),
                          child: const Text('Modifier le moyen de réception'),
                        ),
                    ],
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
