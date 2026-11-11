import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/services/api_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _startDate = DateTime.now().add(const Duration(days: 2));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2, hours: 2));
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await ApiService.fetchGroupEvents();
      if (mounted) setState(() => _events = events);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _insertExample() {
    final start = DateTime.now().add(const Duration(days: 2));
    setState(() {
      _titleController.text = 'Atelier découverte des créateurs locaux';
      _descriptionController.text =
          'Rencontre, démonstrations et échanges avec les artisans de la région.';
      _locationController.text = 'Dakar, Place du Souvenir';
      _startDate = DateTime(start.year, start.month, start.day, 15);
      _endDate = DateTime(start.year, start.month, start.day, 18);
    });
  }

  Future<void> _chooseDateTime({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final chosen = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startDate = chosen;
        if (!_endDate.isAfter(chosen)) {
          _endDate = chosen.add(const Duration(hours: 1));
        }
      } else {
        _endDate = chosen;
      }
    });
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_endDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être après le début.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createGroupEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Événement publié.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publication impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attend(Map<String, dynamic> event) async {
    final id = event['id'];
    if (id is! int) return;
    try {
      await ApiService.attendGroupEvent(id);
      await _loadEvents();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inscription impossible : $error')),
        );
      }
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Événements')),
      backgroundColor: const Color(0xFF020617),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Créer un événement public ou découvrir les prochaines rencontres.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _insertExample,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Remplir avec un exemple'),
            ),
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _textField(
                  'Titre',
                  _titleController,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Le titre est obligatoire.'
                      : null,
                ),
                const SizedBox(height: 12),
                _textField('Description', _descriptionController, maxLines: 3),
                const SizedBox(height: 12),
                _textField('Lieu', _locationController),
                const SizedBox(height: 12),
                _dateButton(
                  'Début',
                  dateFormat.format(_startDate),
                  () => _chooseDateTime(isStart: true),
                ),
                _dateButton(
                  'Fin',
                  dateFormat.format(_endDate),
                  () => _chooseDateTime(isStart: false),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _createEvent,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_available),
                    label: const Text('Publier l’événement'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Événements à venir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ListTile(
              title: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
              trailing: IconButton(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            )
          else if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Aucun événement pour le moment. Publiez le premier.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            ..._events.map((event) {
              final start = DateTime.tryParse('${event['start_date']}');
              final attending = event['is_attending'] == true;
              return Card(
                color: const Color(0xFF111827),
                child: ListTile(
                  title: Text(
                    '${event['title'] ?? 'Événement'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    [
                      if (start != null) dateFormat.format(start.toLocal()),
                      if ('${event['location'] ?? ''}'.isNotEmpty)
                        '${event['location']}',
                      if ('${event['description'] ?? ''}'.isNotEmpty)
                        '${event['description']}',
                    ].join('\n'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: attending ? 'Déjà inscrit' : 'Participer',
                    onPressed: attending ? null : () => _attend(event),
                    icon: Icon(
                      attending ? Icons.check_circle : Icons.event_available,
                      color: attending ? Colors.greenAccent : Colors.lightBlue,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _dateButton(String label, String value, VoidCallback onPressed) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(value, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.edit_calendar, color: Colors.lightBlue),
      onTap: onPressed,
    );
  }
}
