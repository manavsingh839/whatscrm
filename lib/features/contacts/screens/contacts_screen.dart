import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../models/contact_models.dart';
import '../../../services/supabase_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Tag> _tags = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final tags = await SupabaseService.getTags();
      final contacts = await SupabaseService.getContacts(
        searchQuery: _searchQuery,
        tagId: _selectedTagId,
      );
      setState(() {
        _tags = tags;
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditContactDialog([Contact? contact]) {
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final nameController = TextEditingController(text: contact?.name ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    final companyController = TextEditingController(text: contact?.company ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (E.164, e.g. +1234567890)',
                  prefixIcon: Icon(LucideIcons.phone, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(LucideIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(LucideIcons.mail, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  prefixIcon: Icon(LucideIcons.building, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final phone = PhoneUtils.sanitizePhoneForMeta(phoneController.text.trim());
              if (phone.isEmpty) return;

              if (contact == null) {
                await SupabaseService.createContact(
                  phone: phone,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  company: companyController.text.trim(),
                );
              } else {
                await SupabaseService.updateContact(contact.copyWith(
                  phone: phone,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  company: companyController.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadContacts();
            },
            child: Text(contact == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showImportCsvDialog() {
    final csvController = TextEditingController();
    bool isImporting = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Contacts via CSV'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste CSV data below with columns: Name, Phone, Email, Company\n(First row can be headers)',
                  style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: csvController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'John Doe, +14155552671, john@example.com, Acme Inc\nJane Smith, +447911123456, jane@example.com, Globex',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.statusFailed, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isImporting
                  ? null
                  : () async {
                      final raw = csvController.text.trim();
                      if (raw.isEmpty) return;

                      setDialogState(() {
                        isImporting = true;
                        error = null;
                      });

                      try {
                        final rows = csv.decode(raw);
                        int importedCount = 0;

                        for (final row in rows) {
                          if (row.isEmpty) continue;
                          final firstVal = row[0].toString().toLowerCase();
                          if (firstVal.contains('name') || firstVal.contains('phone')) continue;

                          String name = '';
                          String phone = '';
                          String email = '';
                          String company = '';

                          if (row.isNotEmpty) name = row[0].toString().trim();
                          if (row.length >= 2) phone = row[1].toString().trim();
                          if (row.length >= 3) email = row[2].toString().trim();
                          if (row.length >= 4) company = row[3].toString().trim();

                          final sanitizedPhone = PhoneUtils.sanitizePhoneForMeta(phone);
                          if (sanitizedPhone.isNotEmpty) {
                            await SupabaseService.createContact(
                              phone: sanitizedPhone,
                              name: name.isNotEmpty ? name : null,
                              email: email.isNotEmpty ? email : null,
                              company: company.isNotEmpty ? company : null,
                            );
                            importedCount++;
                          }
                        }

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully imported $importedCount contacts!')),
                          );
                          _loadContacts();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isImporting = false;
                          error = 'Import error: $e';
                        });
                      }
                    },
              child: isImporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Import Contacts'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportContactsCsv() {
    final rows = <List<dynamic>>[
      ['Name', 'Phone', 'Email', 'Company', 'Created At'],
    ];

    for (final c in _contacts) {
      rows.add([
        c.name ?? '',
        c.phone,
        c.email ?? '',
        c.company ?? '',
        c.createdAt.toIso8601String(),
      ]);
    }

    final csvString = csv.encode(rows);
    Clipboard.setData(ClipboardData(text: csvString));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${_contacts.length} contacts to CSV (Copied to clipboard)!'),
        action: SnackBarAction(
          label: 'Preview',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Exported CSV Preview'),
                content: SizedBox(
                  width: 500,
                  height: 300,
                  child: SingleChildScrollView(
                    child: SelectableText(csvString),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contacts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_contacts.length} total contacts',
                      style: const TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showImportCsvDialog,
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                    label: const Text('Import CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _exportContactsCsv,
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('Export CSV'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditContactDialog(),
                    icon: const Icon(LucideIcons.userPlus, size: 16),
                    label: const Text('New Contact'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadContacts();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search contacts by name, phone, or company...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Tags', style: TextStyle(fontSize: 11)),
                    selected: _selectedTagId == null,
                    onSelected: (_) {
                      setState(() => _selectedTagId = null);
                      _loadContacts();
                    },
                  ),
                  const SizedBox(width: 6),
                  ..._tags.map((t) {
                    final isSelected = _selectedTagId == t.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(t.name, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedTagId = isSelected ? null : t.id);
                          _loadContacts();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                      ? const Center(child: Text('No contacts found'))
                      : ListView.separated(
                          itemCount: _contacts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: Text(
                                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Row(
                                children: [
                                  Text(contact.phone, style: const TextStyle(color: AppColors.darkTextMuted)),
                                  if (contact.company != null && contact.company!.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.darkTextMuted)),
                                    Text(contact.company!, style: const TextStyle(color: AppColors.darkTextMuted)),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.messageSquare, size: 18, color: AppColors.primary),
                                    tooltip: 'Open Chat',
                                    onPressed: () async {
                                      final conv = await SupabaseService.getOrCreateConversationForContact(contact.id);
                                      if (conv != null && context.mounted) {
                                        context.go('/inbox?id=${conv.id}', extra: conv.id);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.edit2, size: 18),
                                    onPressed: () => _showAddEditContactDialog(contact),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.statusFailed),
                                    onPressed: () async {
                                      await SupabaseService.deleteContact(contact.id);
                                      _loadContacts();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
