import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/automation_models.dart';
import '../../../services/supabase_service.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  List<Automation> _automations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAutomations();
  }

  Future<void> _loadAutomations() async {
    setState(() => _isLoading = true);
    try {
      final items = await SupabaseService.getAutomations();
      setState(() {
        _automations = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading automations: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddAutomationDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final keywordController = TextEditingController();
    final replyController = TextEditingController();

    String selectedTrigger = 'new_message_received';
    String selectedAction = 'send_message';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Automation Rule'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Automation Name (e.g. Welcome Greeting)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Trigger Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTrigger,
                    items: const [
                      DropdownMenuItem(value: 'new_message_received', child: Text('Any New Message')),
                      DropdownMenuItem(value: 'keyword_match', child: Text('Keyword Match (e.g. "order", "price")')),
                      DropdownMenuItem(value: 'new_contact_created', child: Text('New Contact Created')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedTrigger = val);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  if (selectedTrigger == 'keyword_match') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: keywordController,
                      decoration: const InputDecoration(labelText: 'Match Keyword / Phrase'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAction,
                    items: const [
                      DropdownMenuItem(value: 'send_message', child: Text('Send Auto-Reply Message')),
                      DropdownMenuItem(value: 'assign_agent', child: Text('Mark for Human Agent Attention')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedAction = val);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  if (selectedAction == 'send_message') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: replyController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Auto-Reply Text Content'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final triggerConfig = <String, dynamic>{};
                if (selectedTrigger == 'keyword_match') {
                  triggerConfig['keyword'] = keywordController.text.trim().toLowerCase();
                }
                if (selectedAction == 'send_message') {
                  triggerConfig['reply_text'] = replyController.text.trim();
                }

                final auto = Automation(
                  id: '',
                  accountId: '',
                  userId: '',
                  name: name,
                  description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                  triggerType: selectedTrigger,
                  triggerConfig: triggerConfig,
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await SupabaseService.saveAutomation(auto);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadAutomations();
              },
              child: const Text('Create Rule'),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Automations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Trigger actions on incoming WhatsApp messages, keywords, or new contacts',
                      style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddAutomationDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Automation'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _automations.isEmpty
                    ? const Center(child: Text('No automations created yet.'))
                    : ListView.separated(
                        itemCount: _automations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final auto = _automations[index];

                          return Container(
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
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: auto.isActive
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.zap,
                                    color: auto.isActive ? AppColors.primary : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(auto.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Trigger: ${auto.triggerType} • Executions: ${auto.executionCount}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: auto.isActive,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) async {
                                    await SupabaseService.toggleAutomation(auto.id, val);
                                    _loadAutomations();
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.statusFailed),
                                  tooltip: 'Delete Rule',
                                  onPressed: () async {
                                    await SupabaseService.deleteAutomation(auto.id);
                                    _loadAutomations();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
