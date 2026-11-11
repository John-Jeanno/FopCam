import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateJobScreen extends StatefulWidget {
  final int initialTab;

  const CreateJobScreen({super.key, this.initialTab = 1});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _searchTitleController = TextEditingController();
  final _searchLocationController = TextEditingController();
  final _searchDescriptionController = TextEditingController();
  XFile? _searchResume;
  String _jobType = 'full_time';
  String _searchJobType = 'full_time';
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _jobSearches = [];
  List<Map<String, dynamic>> _applications = [];
  int? _currentUserId;
  bool _loading = true;
  bool _loadingSearches = true;
  bool _saving = false;
  bool _savingSearch = false;
  String? _error;
  String? _searchError;

  static const _jobTypes = {
    'full_time': 'Temps plein',
    'part_time': 'Temps partiel',
    'contract': 'Contrat',
    'freelance': 'Freelance',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadJobs();
    _loadJobSearches();
  }

  Future<void> _loadCurrentUser() async {
    final result = await AuthService.getProfile();
    if (!mounted || result['success'] != true) return;
    final user = result['data'];
    if (user is User) setState(() => _currentUserId = user.id);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _searchTitleController.dispose();
    _searchLocationController.dispose();
    _searchDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await ApiService.fetchJobPostings();
      final applications = await ApiService.fetchJobApplications();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _applications = applications;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadJobSearches() async {
    setState(() {
      _loadingSearches = true;
      _searchError = null;
    });
    try {
      final posts = await ApiService.fetchJobSeekerPosts();
      if (mounted) setState(() => _jobSearches = posts);
    } catch (error) {
      if (mounted) setState(() => _searchError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingSearches = false);
    }
  }

  void _insertExample() {
    setState(() {
      _titleController.text = 'Community manager';
      _companyController.text = 'Teranga Créations';
      _locationController.text = 'Dakar';
      _descriptionController.text =
          'Animez nos réseaux sociaux, créez des contenus et échangez avec notre communauté. Une première expérience est appréciée.';
      _salaryMinController.text = '';
      _salaryMaxController.text = '';
      _jobType = 'full_time';
    });
  }

  String? _salaryValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value.trim()) == null) {
      return 'Saisissez un montant numérique.';
    }
    return null;
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate()) return;
    final min = double.tryParse(_salaryMinController.text.trim());
    final max = double.tryParse(_salaryMaxController.text.trim());
    if (min != null && max != null && max < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le salaire maximum doit être supérieur au minimum.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createJobPosting(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        company: _companyController.text.trim(),
        location: _locationController.text.trim(),
        jobType: _jobType,
        salaryMin: _salaryMinController.text.trim(),
        salaryMax: _salaryMaxController.text.trim(),
      );
      if (!mounted) return;
      _titleController.clear();
      _companyController.clear();
      _locationController.clear();
      _descriptionController.clear();
      _salaryMinController.clear();
      _salaryMaxController.clear();
      await _loadJobs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offre d’emploi publiée.')),
        );
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

  bool _isCurrentUsersJob(Map<String, dynamic> job) {
    final employer = job['employer'];
    if (employer is! Map) return false;
    final employerId = employer['id'];
    return employerId == _currentUserId ||
        int.tryParse(employerId?.toString() ?? '') == _currentUserId;
  }

  List<Map<String, dynamic>> _applicationsForJob(Map<String, dynamic> job) {
    final jobId = job['id'];
    return _applications
        .where((application) {
          final applicationJob = application['job'];
          if (applicationJob is! Map) return false;
          return applicationJob['id'] == jobId ||
              int.tryParse(applicationJob['id']?.toString() ?? '') == jobId;
        })
        .toList(growable: false);
  }

  Future<void> _openResume({
    required Future<Map<String, dynamic>> Function() loadLinks,
    required bool download,
  }) async {
    try {
      final links = await loadLinks();
      final value = download ? links['download_url'] : links['view_url'];
      final uri = Uri.tryParse(value?.toString() ?? '');
      if (uri == null || !await launchUrl(uri)) {
        throw StateError('Impossible d’ouvrir le CV.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accès au CV impossible : $error')),
      );
    }
  }

  Future<void> _pickSearchResume() async {
    try {
      final resume = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'CV',
            extensions: ['pdf', 'png', 'jpg', 'jpeg'],
            uniformTypeIdentifiers: [
              'com.adobe.pdf',
              'public.png',
              'public.jpeg',
            ],
          ),
        ],
      );
      if (resume == null || !mounted) return;
      final resumeSize = await resume.length();
      if (!mounted) return;
      if (resumeSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le CV ne peut pas dépasser 10 Mo.')),
        );
        return;
      }
      setState(() => _searchResume = resume);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de choisir le CV : $error')),
      );
    }
  }

  Future<void> _createJobSearch() async {
    if (!_searchFormKey.currentState!.validate()) return;
    setState(() => _savingSearch = true);
    try {
      await ApiService.createJobSeekerPost(
        title: _searchTitleController.text.trim(),
        description: _searchDescriptionController.text.trim(),
        location: _searchLocationController.text.trim(),
        jobType: _searchJobType,
        resume: _searchResume,
      );
      if (!mounted) return;
      _searchTitleController.clear();
      _searchLocationController.clear();
      _searchDescriptionController.clear();
      setState(() => _searchResume = null);
      await _loadJobSearches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre recherche d’emploi est publiée.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publication impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSearch = false);
    }
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final applicant = application['applicant'];
    var applicantName = 'Candidat';
    if (applicant is Map) {
      final fullName = [
        applicant['first_name']?.toString().trim() ?? '',
        applicant['last_name']?.toString().trim() ?? '',
      ].where((name) => name.isNotEmpty).join(' ');
      applicantName = fullName.isNotEmpty
          ? fullName
          : applicant['username']?.toString() ?? 'Candidat';
    }
    final applicationId = application['id'];
    final coverLetter = application['cover_letter']?.toString() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 8),
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(applicantName, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        coverLetter,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: applicationId is int && application['has_resume'] == true
          ? PopupMenuButton<bool>(
              tooltip: 'Accéder au CV',
              icon: const Icon(Icons.description_outlined, color: Colors.amber),
              onSelected: (download) => _openResume(
                loadLinks: () =>
                    ApiService.fetchJobApplicationResumeLinks(applicationId),
                download: download,
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(value: false, child: Text('Consulter le CV')),
                PopupMenuItem(value: true, child: Text('Télécharger le CV')),
              ],
            )
          : null,
    );
  }

  Future<void> _showApplicationForm(Map<String, dynamic> job) async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    XFile? resume;
    var submitting = false;
    final jobId = job['id'];
    if (jobId is! int) return;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Postuler · ${job['title'] ?? 'Offre'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ajoutez une description à votre candidature.'
                        : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description de votre candidature',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            try {
                              final candidate = await openFile(
                                acceptedTypeGroups: const [
                                  XTypeGroup(
                                    label: 'CV',
                                    extensions: ['pdf', 'png', 'jpg', 'jpeg'],
                                    uniformTypeIdentifiers: [
                                      'com.adobe.pdf',
                                      'public.png',
                                      'public.jpeg',
                                    ],
                                  ),
                                ],
                              );
                              if (candidate == null || !context.mounted) {
                                return;
                              }
                              if (await candidate.length() > 10 * 1024 * 1024) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Le CV ne peut pas dépasser 10 Mo.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (context.mounted) {
                                setSheetState(() => resume = candidate);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Impossible de choisir le CV : $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      resume?.name ?? 'Joindre un CV (PDF, PNG, JPEG)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            if (resume == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Veuillez joindre votre CV.'),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => submitting = true);
                            try {
                              await ApiService.applyToJob(
                                jobId: jobId,
                                description: descriptionController.text.trim(),
                                resume: resume!,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                setSheetState(() => submitting = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Candidature impossible : $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Envoyer ma candidature'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    descriptionController.dispose();
    if (applied == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidature envoyée. L’entreprise a été notifiée.'),
        ),
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
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

  Widget _buildOffersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Publiez une offre et consultez les opportunités partagées.',
          style: TextStyle(color: Colors.white70),
        ),
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
              _field(
                'Intitulé du poste',
                _titleController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'L’intitulé est obligatoire.'
                    : null,
              ),
              const SizedBox(height: 12),
              _field('Entreprise', _companyController),
              const SizedBox(height: 12),
              _field('Lieu', _locationController),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _jobType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Type de contrat',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _jobTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _jobType = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Salaire min. (FCFA)',
                      _salaryMinController,
                      keyboardType: TextInputType.number,
                      validator: _salaryValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Salaire max. (FCFA)',
                      _salaryMaxController,
                      keyboardType: TextInputType.number,
                      validator: _salaryValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                'Description',
                _descriptionController,
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'La description est obligatoire.'
                    : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _createJob,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.work_outline),
                  label: const Text('Publier l’offre'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Offres disponibles',
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
              onPressed: _loadJobs,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          )
        else if (_jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Aucune offre pour le moment. Publiez la première.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ..._jobs.map((job) {
            final applications = _isCurrentUsersJob(job)
                ? _applicationsForJob(job)
                : const <Map<String, dynamic>>[];
            return Card(
              color: const Color(0xFF111827),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${job['title'] ?? 'Poste'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [
                          if ('${job['company'] ?? ''}'.isNotEmpty)
                            '${job['company']}',
                          if ('${job['location'] ?? ''}'.isNotEmpty)
                            '${job['location']}',
                          _jobTypes['${job['job_type']}'] ?? '',
                          if ('${job['description'] ?? ''}'.isNotEmpty)
                            '${job['description']}',
                        ].where((line) => line.isNotEmpty).join('\n'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: TextButton(
                        onPressed: () => _showApplicationForm(job),
                        child: const Text('Je postule'),
                      ),
                      isThreeLine: true,
                    ),
                    if (_isCurrentUsersJob(job)) ...[
                      const Divider(color: Colors.white24),
                      Text(
                        'Candidatures reçues (${applications.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (applications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucune candidature pour le moment.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        ...applications.map(_buildApplicationCard),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildJobSearchTab() {
    return Form(
      key: _searchFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Publiez le poste que vous recherchez et soyez visible des entreprises.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          _field(
            'Poste recherché',
            _searchTitleController,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Le poste recherché est obligatoire.'
                : null,
          ),
          const SizedBox(height: 12),
          _field('Lieu souhaité', _searchLocationController),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _searchJobType,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Type de contrat recherché',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _jobTypes.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _searchJobType = value);
            },
          ),
          const SizedBox(height: 12),
          _field(
            'Présentez votre expérience et vos compétences',
            _searchDescriptionController,
            maxLines: 4,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'La description est obligatoire.'
                : null,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickSearchResume,
            icon: const Icon(Icons.attach_file),
            label: Text(_searchResume?.name ?? 'Joindre mon CV (facultatif)'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingSearch ? null : _createJobSearch,
            icon: _savingSearch
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Publier ma recherche'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Personnes en recherche d’emploi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_loadingSearches)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchError != null)
            ListTile(
              title: Text(
                _searchError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
              trailing: IconButton(
                onPressed: _loadJobSearches,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            )
          else if (_jobSearches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Aucune recherche publiée pour le moment.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            ..._jobSearches.map((post) {
              final author = post['author'];
              final authorName = author is Map
                  ? (author['first_name']?.toString().trim().isNotEmpty == true
                        ? author['first_name'].toString()
                        : author['username']?.toString() ?? 'Utilisateur')
                  : 'Utilisateur';
              return Card(
                color: const Color(0xFF111827),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${post['title'] ?? 'Poste recherché'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            authorName,
                            if ('${post['location'] ?? ''}'.isNotEmpty)
                              '${post['location']}',
                            _jobTypes['${post['job_type']}'] ?? '',
                            if ('${post['description'] ?? ''}'.isNotEmpty)
                              '${post['description']}',
                          ].where((line) => line.isNotEmpty).join('\n'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        isThreeLine: true,
                      ),
                      if (_jobs.any(_isCurrentUsersJob) &&
                          post['has_resume'] == true &&
                          post['id'] is int)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openResume(
                                loadLinks: () =>
                                    ApiService.fetchJobSeekerResumeLinks(
                                      post['id'] as int,
                                    ),
                                download: false,
                              ),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Consulter le CV'),
                            ),
                            TextButton.icon(
                              onPressed: () => _openResume(
                                loadLinks: () =>
                                    ApiService.fetchJobSeekerResumeLinks(
                                      post['id'] as int,
                                    ),
                                download: true,
                              ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Télécharger'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emploi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recherche d’emploi'),
              Tab(text: 'Offres d’emploi'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF020617),
        body: TabBarView(children: [_buildJobSearchTab(), _buildOffersTab()]),
      ),
    );
  }
}
