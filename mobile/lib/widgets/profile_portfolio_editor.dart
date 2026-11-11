import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';

const _portfolioDialogColor = Color(0xFF581A1A);
const _portfolioPrimaryColor = Color(0xFF991B1B);

class ProfilePortfolioEditor extends StatefulWidget {
  const ProfilePortfolioEditor({super.key, required this.user});

  final User user;

  @override
  State<ProfilePortfolioEditor> createState() => _ProfilePortfolioEditorState();
}

class _ProfilePortfolioEditorState extends State<ProfilePortfolioEditor> {
  late Map<String, List<Map<String, dynamic>>> _entries;
  bool _isSaving = false;

  static const _sections = [
    _PortfolioSection(
      title: 'Expériences et parcours',
      field: 'experience_and_journey',
      fields: [
        'title',
        'organization',
        'location',
        'start_date',
        'end_date',
        'description',
      ],
    ),
    _PortfolioSection(
      title: 'Profil et formations',
      field: 'education_and_training',
      fields: ['title', 'institution', 'start_date', 'end_date', 'description'],
    ),
    _PortfolioSection(
      title: 'Mes compétences',
      field: 'skills',
      fields: ['title', 'level', 'description'],
    ),
    _PortfolioSection(
      title: 'Mes services',
      field: 'services',
      fields: ['title', 'description', 'price'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entries = _copyUserEntries(widget.user);
  }

  @override
  void didUpdateWidget(covariant ProfilePortfolioEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _entries = _copyUserEntries(widget.user);
    }
  }

  Map<String, List<Map<String, dynamic>>> _copyUserEntries(User user) => {
    'experience_and_journey': user.experienceAndJourney
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(),
    'education_and_training': user.educationAndTraining
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(),
    'skills': user.skills
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(),
    'services': user.services
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(),
  };

  Future<void> _saveSection(
    _PortfolioSection section,
    List<Map<String, dynamic>> entries,
  ) async {
    setState(() => _isSaving = true);
    final result = await ApiService.updateProfile({section.field: entries});
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enregistrement impossible : ${result['error'] ?? 'Veuillez réessayer.'}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _entries[section.field] = entries);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rubrique du profil mise à jour.')),
    );
  }

  Future<void> _editEntry(
    _PortfolioSection section, {
    Map<String, dynamic>? existing,
  }) async {
    final controllers = {
      for (final field in section.fields)
        field: TextEditingController(
          text: _initialFieldValue(field, existing?[field]?.toString() ?? ''),
        ),
    };
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dialogTheme = theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            brightness: Brightness.dark,
            primary: const Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: _portfolioDialogColor,
            onSurface: Colors.white,
            primaryContainer: _portfolioPrimaryColor,
            onPrimaryContainer: Colors.white,
            error: const Color(0xFFFF8A80),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        );
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            backgroundColor: _portfolioDialogColor,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
            contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
            title: Text(
              '${existing == null ? 'Ajouter' : 'Modifier'} · ${section.title}',
            ),
            content: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.58,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final field in section.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEntryField(
                            dialogContext,
                            field,
                            controllers[field]!,
                            controllers,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _portfolioPrimaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final values = <String, dynamic>{
                    for (final field in section.fields)
                      field: _apiFieldValue(
                        field,
                        controllers[field]!.text.trim(),
                      ),
                  };
                  if (section.fields.contains('price')) {
                    final priceText = values['price'] as String;
                    values['price'] = priceText.isEmpty
                        ? null
                        : double.parse(
                            priceText.replaceAll(',', '.'),
                          ).toStringAsFixed(2);
                    values['currency'] = 'FCFA';
                  }
                  Navigator.pop(dialogContext, values);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (!mounted || result == null) return;

    final entries = List<Map<String, dynamic>>.from(_entries[section.field]!);
    final index = existing == null ? -1 : entries.indexOf(existing);
    if (index < 0) {
      entries.add(result);
    } else {
      entries[index] = result;
    }
    await _saveSection(section, entries);
  }

  Widget _buildEntryField(
    BuildContext dialogContext,
    String field,
    TextEditingController controller,
    Map<String, TextEditingController> controllers,
  ) {
    final isDate = field == 'start_date' || field == 'end_date';
    return TextFormField(
      controller: controller,
      readOnly: isDate,
      onTap: isDate
          ? () => _selectDate(dialogContext, field, controllers)
          : null,
      maxLines: field == 'description' ? 3 : 1,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      keyboardType: field == 'price'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: _entryFieldLabel(field),
        labelStyle: const TextStyle(color: Colors.white),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        suffixIcon: isDate
            ? IconButton(
                tooltip: 'Choisir ${_entryFieldLabel(field).toLowerCase()}',
                onPressed: () => _selectDate(dialogContext, field, controllers),
                icon: const Icon(Icons.calendar_month, color: Colors.white),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF8A80)),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF8A80), width: 2),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        errorStyle: const TextStyle(color: Colors.white),
      ),
      validator: field == 'title'
          ? (value) => value == null || value.trim().isEmpty
                ? 'Ce champ est obligatoire.'
                : null
          : field == 'price'
          ? (value) {
              if (value == null || value.trim().isEmpty) return null;
              final price = double.tryParse(value.trim().replaceAll(',', '.'));
              return price == null || !price.isFinite || price < 0
                  ? 'Saisissez un prix positif valide.'
                  : null;
            }
          : null,
    );
  }

  Future<void> _selectDate(
    BuildContext dialogContext,
    String field,
    Map<String, TextEditingController> controllers,
  ) async {
    final controller = controllers[field]!;
    final currentDate = _parsePortfolioDate(controller.text) ?? DateTime.now();
    final theme = Theme.of(dialogContext);
    final selectedDate = await showDatePicker(
      context: dialogContext,
      initialDate: DateTime(
        currentDate.year.clamp(1900, 2100).toInt(),
        currentDate.month,
        currentDate.day,
      ),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: _entryFieldLabel(field),
      builder: (context, child) => Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            brightness: Brightness.dark,
            primary: const Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: _portfolioDialogColor,
            onSurface: Colors.white,
            primaryContainer: _portfolioPrimaryColor,
            onPrimaryContainer: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ),
        child: child!,
      ),
    );
    if (selectedDate == null || !mounted) return;

    controller.text = DateFormat('dd/MM/yyyy').format(selectedDate);
  }

  String _initialFieldValue(String field, String value) {
    if (field != 'start_date' && field != 'end_date') return value;
    final parsed = _parsePortfolioDate(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _apiFieldValue(String field, String value) {
    if (field == 'start_date' || field == 'end_date') {
      final parsed = _parsePortfolioDate(value);
      if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
    }
    return value;
  }

  DateTime? _parsePortfolioDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parsedDisplayDate = DateFormat(
      'dd/MM/yyyy',
    ).tryParseStrict(normalized);
    if (parsedDisplayDate != null) return parsedDisplayDate;
    final parsedIsoDate = DateTime.tryParse(normalized);
    if (parsedIsoDate != null) return parsedIsoDate;
    if (RegExp(r'^\d{4}$').hasMatch(normalized)) {
      return DateTime(int.parse(normalized));
    }
    return null;
  }

  Future<void> _deleteEntry(
    _PortfolioSection section,
    Map<String, dynamic> entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet élément ?'),
        content: const Text('Cette action sera enregistrée sur votre profil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final entries = List<Map<String, dynamic>>.from(_entries[section.field]!);
    entries.remove(entry);
    await _saveSection(section, entries);
  }

  String _entryFieldLabel(String field) => switch (field) {
    'title' => 'Intitulé',
    'organization' => 'Entreprise / organisation',
    'institution' => 'Établissement',
    'location' => 'Lieu',
    'level' => 'Niveau',
    'start_date' => 'Date de début',
    'end_date' => 'Date de fin',
    'description' => 'Description',
    'price' => 'Prix (facultatif, FCFA)',
    _ => field,
  };

  Widget _buildSection(_PortfolioSection section) {
    final entries = _entries[section.field]!;
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : () => _editEntry(section),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (entries.isEmpty)
              const Text(
                'Aucun élément ajouté.',
                style: TextStyle(color: Colors.white60),
              ),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry['title']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                        entry['organization'],
                        entry['institution'],
                        entry['location'],
                        entry['level'],
                        entry['start_date'],
                        entry['end_date'],
                        entry['price'] == null
                            ? null
                            : '${entry['price']} FCFA',
                        entry['description']?.toString().trim().isNotEmpty ==
                                true
                            ? entry['description']
                            : null,
                      ]
                      .where(
                        (value) =>
                            value != null && value.toString().trim().isNotEmpty,
                      )
                      .join(' · '),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Modifier',
                      onPressed: _isSaving
                          ? null
                          : () => _editEntry(section, existing: entry),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: _isSaving
                          ? null
                          : () => _deleteEntry(section, entry),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Expériences, formations, compétences et services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 1000
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final section in _sections)
                  SizedBox(width: itemWidth, child: _buildSection(section)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PortfolioSection {
  const _PortfolioSection({
    required this.title,
    required this.field,
    required this.fields,
  });

  final String title;
  final String field;
  final List<String> fields;
}
