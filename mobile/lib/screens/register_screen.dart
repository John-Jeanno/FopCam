// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:country_picker/country_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/app_locale_service.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _motorcyclePlateController = TextEditingController();
  late FocusNode _emailFocus;
  late FocusNode _usernameFocus;
  late FocusNode _firstNameFocus;
  late FocusNode _lastNameFocus;
  late FocusNode _passwordFocus;
  String _selectedUserType = 'particular';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  final Map<String, String> _fieldErrors = {};
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  String? _locationError;
  String _selectedCountryCode = '';
  String _registrationLanguage = 'fr';

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _motorcyclePlateController.dispose();
    _emailFocus.dispose();
    _usernameFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _usernameFocus = FocusNode();
    _firstNameFocus = FocusNode();
    _lastNameFocus = FocusNode();
    _passwordFocus = FocusNode();
    _requestDeviceLocation();
  }

  Future<void> _requestDeviceLocation() async {
    if (!mounted) return;
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locationError = 'Permission de localisation refusée.';
          _locationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLoading = false;
        _locationError = null;
      });

      if (kIsWeb) {
        setState(() {
          _locationError =
              'La position est détectée. Saisissez l’adresse et la ville manuellement dans le navigateur.';
        });
        return;
      }

      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (!mounted) return;
        final placemark = placemarks.isEmpty ? null : placemarks.first;
        if (placemark == null) {
          setState(() {
            _locationError =
                'Adresse introuvable. Vous pouvez remplir les champs manuellement.';
          });
          return;
        }
        final street = [
          placemark.subThoroughfare,
          placemark.thoroughfare,
          placemark.subLocality,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
        final city =
            placemark.locality ??
            placemark.subAdministrativeArea ??
            placemark.administrativeArea;
        final country = placemark.country;
        setState(() {
          if (_addressController.text.trim().isEmpty && street.isNotEmpty) {
            _addressController.text = street;
          }
          if (_cityController.text.trim().isEmpty && city?.isNotEmpty == true) {
            _cityController.text = city!;
          }
          if (_countryController.text.trim().isEmpty &&
              country?.isNotEmpty == true) {
            _countryController.text = country!;
            _selectedCountryCode = placemark.isoCountryCode ?? '';
            _registrationLanguage =
                AppLocaleService.languageForCountry(_selectedCountryCode) ??
                AppLocaleService.localeTag(AppLocaleService.locale.value);
          }
        });
      } on Object catch (error) {
        debugPrint('Reverse geocoding failed: $error');
        if (!mounted) return;
        setState(() {
          _locationError =
              'Adresse introuvable automatiquement. Vous pouvez remplir les champs manuellement.';
        });
      }
    } on Object catch (error) {
      debugPrint('Location lookup failed: $error');
      if (!mounted) return;
      setState(() {
        _locationError =
            'Position indisponible. Vous pouvez remplir les champs manuellement.';
        _locationLoading = false;
      });
    }
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: const ['SN'],
      onSelect: (country) {
        setState(() {
          _countryController.text =
              country.getTranslatedName(context) ?? country.name;
          _selectedCountryCode = country.countryCode;
          _registrationLanguage =
              AppLocaleService.languageForCountry(country.countryCode) ??
              AppLocaleService.localeTag(AppLocaleService.locale.value);
        });
        _clearFieldError('country');
      },
    );
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors.clear();
    });
    final result = await AuthService.register(
      _emailController.text,
      _passwordController.text,
      _usernameController.text,
      _firstNameController.text,
      _lastNameController.text,
      _phoneController.text,
      _addressController.text,
      _cityController.text,
      _countryController.text,
      _selectedUserType,
      _motorcyclePlateController.text,
      _latitude,
      _longitude,
      countryCode: _selectedCountryCode,
      preferredLanguage: _registrationLanguage,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      await AppLocaleService.setLanguage(_registrationLanguage);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Inscription réussie'),
          content: Text(
            'Votre compte a bien été créé. Vous pouvez maintenant vous '
            'connecter avec le nom d’utilisateur « '
            '${_usernameController.text.trim()} » et le mot de passe choisi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continuer vers la connexion'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              LoginScreen(initialUsername: _usernameController.text.trim()),
        ),
      );
    } else {
      setState(() {
        final fieldErrors = AuthService.fieldErrors(result['fieldErrors']);
        _fieldErrors.addAll(fieldErrors);
        _errorMessage = fieldErrors.isEmpty
            ? AuthService.formatAuthError(result['error'], isRegistration: true)
            : null;
      });
    }
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field) || _errorMessage != null) {
      setState(() {
        _fieldErrors.remove(field);
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Container(
                      width: 140,
                      height: 140,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.08),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/images/fopcam-logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const Text(
                      'Créer un compte FopCam',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rejoignez la communauté pour acheter et vendre en circuit court.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFBFC6D4),
                        fontSize: 14.5,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.08),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.22),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          TextField(
                            focusNode: _emailFocus,
                            onTap: () => _emailFocus.requestFocus(),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              errorText: _fieldErrors['email'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Entrez votre email',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('email'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            focusNode: _usernameFocus,
                            onTap: () => _usernameFocus.requestFocus(),
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Nom d\'utilisateur',
                              errorText: _fieldErrors['username'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Choisissez un pseudo',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('username'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            focusNode: _firstNameFocus,
                            onTap: () => _firstNameFocus.requestFocus(),
                            controller: _firstNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Prénom',
                              errorText: _fieldErrors['first_name'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre prénom',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('first_name'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            focusNode: _lastNameFocus,
                            onTap: () => _lastNameFocus.requestFocus(),
                            controller: _lastNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Nom',
                              errorText: _fieldErrors['last_name'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre nom',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('last_name'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Téléphone',
                              errorText: _fieldErrors['phone'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre numéro de téléphone',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('phone'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _addressController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              errorText: _fieldErrors['address'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre adresse',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('address'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _cityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Ville',
                              errorText: _fieldErrors['city'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre ville',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('city'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _countryController,
                            readOnly: true,
                            onTap: _selectCountry,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Pays',
                              errorText: _fieldErrors['country'],
                              suffixIcon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF94A3B8),
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Votre pays',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Type d\'utilisateur',
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUserType,
                                dropdownColor: const Color(0xFF111827),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'particular',
                                    child: Text('Acheteur'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'producer',
                                    child: Text('Producteur'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'boutique',
                                    child: Text('Boutique'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'prestataire',
                                    child: Text('Prestataire'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'enterprise',
                                    child: Text('Entreprise'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'influencer',
                                    child: Text('Influenceur'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'community_lead',
                                    child: Text('Responsable Communautaire'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'driver',
                                    child: Text('Livreur'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedUserType = value;
                                    });
                                  }
                                },
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          if (_selectedUserType == 'driver') ...[
                            const SizedBox(height: 16),
                            TextField(
                              // Removed unnecessary focusNode
                              controller: _motorcyclePlateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Immatriculation moto',
                                errorText: _fieldErrors['motorcycle_plate'],
                                labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                                hintText: 'Exemple : AB-123-CD',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111827),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.08,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.08,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF991B1B),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (_) =>
                                  _clearFieldError('motorcycle_plate'),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            focusNode: _passwordFocus,
                            onTap: () => _passwordFocus.requestFocus(),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              errorText: _fieldErrors['password'],
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              hintText: 'Créez un mot de passe sécurisé',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF991B1B),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _clearFieldError('password'),
                          ),
                          const SizedBox(height: 28),
                          if (_locationLoading)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.03,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.06,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  CircularProgressIndicator(strokeWidth: 2),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Obtention de votre position...',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_locationLoading &&
                              _latitude != null &&
                              _longitude != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(0, 128, 0, 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(0, 128, 0, 0.08),
                                ),
                              ),
                              child: Text('Position détectée automatiquement.'),
                            ),
                          if (!_locationLoading && _locationError != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(128, 0, 0, 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color.fromRGBO(128, 0, 0, 0.08),
                                ),
                              ),
                              child: Text(
                                _locationError ?? 'Localisation indisponible.',
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF991B1B),
                                    Color(0xFF7F1D1D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Color.fromRGBO(153, 27, 27, 0.35),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  _isLoading
                                      ? 'Création...'
                                      : 'Créer un compte',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Vous avez déjà un compte ? ',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '© 2025 FopCam - Le premier réseau social et marketplace en circuit court',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
