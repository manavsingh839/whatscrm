import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/contact_models.dart';
import '../../../models/pipeline_models.dart';
import '../../../services/supabase_service.dart';

class PipelinesScreen extends StatefulWidget {
  const PipelinesScreen({super.key});

  @override
  State<PipelinesScreen> createState() => _PipelinesScreenState();
}

class _PipelinesScreenState extends State<PipelinesScreen> {
  List<Pipeline> _pipelines = [];
  Pipeline? _selectedPipeline;
  List<PipelineStage> _stages = [];
  List<Deal> _deals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPipelines();
  }

  Future<void> _loadPipelines() async {
    setState(() => _isLoading = true);
    try {
      final pipelines = await SupabaseService.getPipelines();
      if (pipelines.isNotEmpty) {
        _selectedPipeline = pipelines.first;
        await _loadPipelineData(_selectedPipeline!.id);
      }
      setState(() {
        _pipelines = pipelines;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pipelines: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPipelineData(String pipelineId) async {
    final stages = await SupabaseService.getPipelineStages(pipelineId);
    final deals = await SupabaseService.getDeals(pipelineId);
    setState(() {
      _stages = stages;
      _deals = deals;
    });
  }

  double get _totalPipelineValue =>
      _deals.fold(0.0, (sum, deal) => sum + deal.value);

  int get _wonDealsCount =>
      _deals.where((d) => d.status == DealStatus.won).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sales Pipelines', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${_deals.length} deals ($_wonDealsCount won) • \$${_totalPipelineValue.toStringAsFixed(0)} pipeline value',
                    style: const TextStyle(fontSize: 13, color: AppColors.darkTextMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_pipelines.length > 1) ...[
                    DropdownButton<Pipeline>(
                      value: _selectedPipeline,
                      items: _pipelines.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setState(() => _selectedPipeline = p);
                          _loadPipelineData(p.id);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _showAddStageDialog,
                    icon: const Icon(LucideIcons.listPlus, size: 16),
                    label: const Text('Add Stage'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDealDialog(),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add Deal'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Kanban Columns View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stages.isEmpty
                    ? const Center(child: Text('No pipeline stages configured'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final stage = _stages[index];
                          final stageDeals = _deals.where((d) => d.stageId == stage.id).toList();
                          final stageValue = stageDeals.fold(0.0, (sum, d) => sum + d.value);

                          return Container(
                            width: 300,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Stage Header
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 5,
                                            backgroundColor: Color(int.parse(stage.color.replaceFirst('#', '0xFF'))),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(stage.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                      Text(
                                        '\$${stageValue.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),

                                // Deals List inside Column
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(10),
                                    itemCount: stageDeals.length,
                                    itemBuilder: (context, dIdx) {
                                      final deal = stageDeals[dIdx];

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          side: BorderSide(
                                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        color: isDark ? AppColors.darkSurface : const Color(0xFFFAFAFA),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      deal.title,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ),
                                                  Text(
                                                    '\$${deal.value.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.whatsappGreen),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              if (deal.contact != null) ...[
                                                Row(
                                                  children: [
                                                    const Icon(LucideIcons.user, size: 12, color: AppColors.darkTextMuted),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      deal.contact!.displayName,
                                                      style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                                                    ),
                                                    const Spacer(),
                                                    InkWell(
                                                      onTap: () async {
                                                        final conv = await SupabaseService.getOrCreateConversationForContact(deal.contactId!);
                                                        if (conv != null && context.mounted) {
                                                          context.go('/inbox?id=${conv.id}', extra: conv.id);
                                                        }
                                                      },
                                                      child: const Icon(LucideIcons.messageSquare, size: 14, color: AppColors.primary),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              // Move to next stage button
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  if (index > 0)
                                                    IconButton(
                                                      icon: const Icon(LucideIcons.chevronLeft, size: 14),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () async {
                                                        await SupabaseService.updateDealStage(deal.id, _stages[index - 1].id);
                                                        if (_selectedPipeline != null) {
                                                          _loadPipelineData(_selectedPipeline!.id);
                                                        }
                                                      },
                                                    ),
                                                  if (index < _stages.length - 1) ...[
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(LucideIcons.chevronRight, size: 14),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () async {
                                                        await SupabaseService.updateDealStage(deal.id, _stages[index + 1].id);
                                                        if (_selectedPipeline != null) {
                                                          _loadPipelineData(_selectedPipeline!.id);
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddStageDialog() {
    final nameController = TextEditingController();
    String selectedColor = '#25D366';
    final colors = ['#25D366', '#3B82F6', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Pipeline Stage'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Stage Name (e.g. Qualified, Proposal, Won)',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Stage Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: colors.map((c) {
                    final isSel = selectedColor == c;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isSel ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty || _selectedPipeline == null) return;

                await SupabaseService.createPipelineStage(
                  pipelineId: _selectedPipeline!.id,
                  name: name,
                  position: _stages.length,
                  color: selectedColor,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadPipelineData(_selectedPipeline!.id);
              },
              child: const Text('Add Stage'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDealDialog() async {
    final contacts = await SupabaseService.getContacts();
    if (!mounted) return;

    final titleController = TextEditingController();
    final valueController = TextEditingController(text: '0');
    Contact? selectedContact = contacts.isNotEmpty ? contacts.first : null;
    PipelineStage? selectedStage = _stages.isNotEmpty ? _stages.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Deal'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Deal Name')),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Deal Value (USD)'),
                ),
                const SizedBox(height: 12),
                if (contacts.isNotEmpty) ...[
                  const Text('Associated Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Contact>(
                    initialValue: selectedContact,
                    items: contacts.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.displayName));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedContact = val),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_stages.isNotEmpty) ...[
                  const Text('Stage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<PipelineStage>(
                    initialValue: selectedStage,
                    items: _stages.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedStage = val),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = SupabaseService.currentUser;
                if (_selectedPipeline != null && selectedStage != null) {
                  await SupabaseService.createDeal(
                    Deal(
                      id: '',
                      userId: user?.id ?? '',
                      pipelineId: _selectedPipeline!.id,
                      stageId: selectedStage!.id,
                      contactId: selectedContact?.id,
                      title: titleController.text.trim(),
                      value: double.tryParse(valueController.text.trim()) ?? 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  _loadPipelineData(_selectedPipeline!.id);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
