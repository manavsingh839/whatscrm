import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/broadcast_models.dart';
import '../../../models/contact_models.dart';
import '../../../models/whatsapp_models.dart';
import '../../../services/meta_api_service.dart';
import '../../../services/supabase_service.dart';

class BroadcastsScreen extends StatefulWidget {
  const BroadcastsScreen({super.key});

  @override
  State<BroadcastsScreen> createState() => _BroadcastsScreenState();
}

class _BroadcastsScreenState extends State<BroadcastsScreen> {
  List<Broadcast> _broadcasts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    try {
      final bcasts = await SupabaseService.getBroadcasts();
      setState(() {
        _broadcasts = bcasts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading broadcasts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showCreateBroadcastDialog() async {
    final templates = await SupabaseService.getMessageTemplates();
    final tags = await SupabaseService.getTags();

    if (!mounted) return;

    final nameController = TextEditingController();
    MessageTemplate? selectedTemplate = templates.isNotEmpty ? templates.first : null;
    Tag? selectedTag;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Broadcast Campaign'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Campaign Name (e.g. Special Offer)'),
                ),
                const SizedBox(height: 16),
                const Text('Select Meta Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<MessageTemplate>(
                  initialValue: selectedTemplate,
                  items: templates.map((t) {
                    return DropdownMenuItem(value: t, child: Text('${t.name} (${t.language})'));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedTemplate = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Audience Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Tag?>(
                  initialValue: selectedTag,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Contacts')),
                    ...tags.map((t) => DropdownMenuItem(value: t, child: Text('Tagged: ${t.name}'))),
                  ],
                  onChanged: (val) => setDialogState(() => selectedTag = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = SupabaseService.currentUser;
                final name = nameController.text.trim();
                if (name.isEmpty || selectedTemplate == null) return;

                final newBcast = Broadcast(
                  id: '',
                  userId: user?.id ?? '',
                  name: name,
                  templateName: selectedTemplate!.name,
                  templateLanguage: selectedTemplate!.language,
                  audienceFilter: selectedTag != null ? {'tag_id': selectedTag!.id} : null,
                  status: BroadcastStatus.draft,
                  createdAt: DateTime.now(),
                );

                await SupabaseService.createBroadcast(newBcast);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadBroadcasts();
              },
              child: const Text('Create Campaign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCampaign(Broadcast bcast) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start Campaign: ${bcast.name}'),
        content: Text(
          'Are you sure you want to send template "${bcast.templateName}" to the target audience now?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _executeBroadcastSend(bcast);
            },
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBroadcastSend(Broadcast bcast) async {
    setState(() => _isLoading = true);
    try {
      final tagId = bcast.audienceFilter?['tag_id'] as String?;
      final targetContacts = await SupabaseService.getContacts(tagId: tagId);

      final waConfig = await SupabaseService.getWhatsAppConfig();
      if (waConfig == null || !waConfig.isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot send campaign: WhatsApp API is not connected. Please configure and test connection in Settings.'),
              backgroundColor: AppColors.statusFailed,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      int sentCount = 0;
      int failedCount = 0;

      for (final contact in targetContacts) {
        final phone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
        if (phone.isEmpty) continue;

        try {
          await MetaApiService.sendTemplateMessage(
            phoneNumberId: waConfig.phoneNumberId,
            accessToken: waConfig.accessToken,
            to: phone,
            templateName: bcast.templateName,
            languageCode: bcast.templateLanguage,
          );

          await SupabaseService.client.from('broadcast_recipients').insert({
            'broadcast_id': bcast.id,
            'contact_id': contact.id,
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          });
          sentCount++;
        } catch (e) {
          debugPrint('Recipient send note: $e');
          await SupabaseService.client.from('broadcast_recipients').insert({
            'broadcast_id': bcast.id,
            'contact_id': contact.id,
            'status': 'failed',
            'error_message': e.toString(),
            'sent_at': DateTime.now().toIso8601String(),
          });
          failedCount++;
        }
      }

      await SupabaseService.client.from('broadcasts').update({
        'status': failedCount > 0 && sentCount == 0 ? 'failed' : 'sent',
        'total_recipients': targetContacts.length,
        'sent_count': sentCount,
        'delivered_count': sentCount,
      }).eq('id', bcast.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign sent to $sentCount recipients!')),
        );
      }
      _loadBroadcasts();
    } catch (e) {
      debugPrint('Broadcast send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBroadcastDetails(Broadcast bcast) async {
    final recipients = await SupabaseService.getBroadcastRecipients(bcast.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bcast.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Template: ${bcast.templateName} (${bcast.templateLanguage})',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
                  ],
                ),
                _buildStatusBadge(bcast.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetric('Total', '${bcast.totalRecipients}'),
                const SizedBox(width: 20),
                _buildMetric('Sent', '${bcast.sentCount}'),
                const SizedBox(width: 20),
                _buildMetric('Delivered', '${bcast.deliveredCount}'),
                const SizedBox(width: 20),
                _buildMetric('Read', '${bcast.readCount}'),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Recipients Delivery Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: recipients.isEmpty
                ? const Center(
                    child: Text('No recipients registered yet.',
                        style: TextStyle(color: AppColors.darkTextMuted)),
                  )
                : ListView.separated(
                    itemCount: recipients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final r = recipients[idx];
                      return ListTile(
                        title: Text(r.contact?.displayName ?? (r.contactId ?? 'Unknown'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(r.contact?.phone ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
                        trailing: Text(
                          r.status.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                        ),
                      );
                    },
                  ),
            ),
          ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Broadcasts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Send template messages to audiences at scale with live tracking',
                      style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateBroadcastDialog,
                icon: const Icon(LucideIcons.send, size: 16),
                label: const Text('New Broadcast'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _broadcasts.isEmpty
                    ? const Center(child: Text('No broadcast campaigns created yet.'))
                    : ListView.separated(
                        itemCount: _broadcasts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bcast = _broadcasts[index];

                          return InkWell(
                            onTap: () => _showBroadcastDetails(bcast),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(LucideIcons.megaphone, color: AppColors.primary, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(bcast.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(width: 10),
                                            _buildStatusBadge(bcast.status),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Template: ${bcast.templateName} (${bcast.templateLanguage}) • Created ${DateFormatter.formatRelative(bcast.createdAt)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Metrics counters
                                  Row(
                                    children: [
                                      _buildMetric('Total', '${bcast.totalRecipients}'),
                                      const SizedBox(width: 16),
                                      _buildMetric('Sent', '${bcast.sentCount}'),
                                      const SizedBox(width: 16),
                                      _buildMetric('Delivered', '${bcast.deliveredCount}'),
                                      const SizedBox(width: 16),
                                      _buildMetric('Read', '${bcast.readCount}'),
                                    ],
                                  ),
                                  if (bcast.status == BroadcastStatus.draft) ...[
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed: () => _startCampaign(bcast),
                                      child: const Text('Send'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
      ],
    );
  }

  Widget _buildStatusBadge(BroadcastStatus status) {
    Color color;
    switch (status) {
      case BroadcastStatus.draft:
        color = AppColors.statusSending;
        break;
      case BroadcastStatus.scheduled:
        color = AppColors.statusPending;
        break;
      case BroadcastStatus.sending:
        color = AppColors.statusOpen;
        break;
      case BroadcastStatus.sent:
        color = AppColors.statusClosed;
        break;
      case BroadcastStatus.failed:
        color = AppColors.statusFailed;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
