import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flow_models.dart';
import '../../../services/supabase_service.dart';

class FlowsScreen extends StatefulWidget {
  const FlowsScreen({super.key});

  @override
  State<FlowsScreen> createState() => _FlowsScreenState();
}

class _FlowsScreenState extends State<FlowsScreen> {
  List<FlowRow> _flows = [];
  FlowRow? _activeFlow;
  List<FlowNodeRow> _nodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlows();
  }

  Future<void> _loadFlows() async {
    setState(() => _isLoading = true);
    try {
      final flows = await SupabaseService.getFlows();
      setState(() {
        _flows = flows;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading flows: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFlowCanvas(FlowRow flow) async {
    final nodes = await SupabaseService.getFlowNodes(flow.id);
    setState(() {
      _activeFlow = flow;
      _nodes = nodes;
    });
  }

  void _showCreateFlowDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String triggerType = 'keyword';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Visual Flow'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Flow Name (e.g. Sales Onboarding)'),
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
                  initialValue: triggerType,
                  items: const [
                    DropdownMenuItem(value: 'keyword', child: Text('Trigger on Keyword')),
                    DropdownMenuItem(value: 'new_message', child: Text('Trigger on Any Message')),
                    DropdownMenuItem(value: 'webhook', child: Text('Trigger via Webhook / API')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => triggerType = val);
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final flow = FlowRow(
                  id: '',
                  accountId: '',
                  userId: '',
                  name: name,
                  description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                  triggerType: triggerType,
                  status: 'active',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await SupabaseService.saveFlow(flow);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadFlows();
              },
              child: const Text('Create Flow'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNodeDialog() {
    final keyController = TextEditingController();
    final textController = TextEditingController();
    String nodeType = 'message';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Canvas Node'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Node Identifier (e.g. send_welcome, ask_budget)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Node Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: nodeType,
                  items: const [
                    DropdownMenuItem(value: 'message', child: Text('Send WhatsApp Message')),
                    DropdownMenuItem(value: 'question', child: Text('Ask Question & Wait for Reply')),
                    DropdownMenuItem(value: 'condition', child: Text('Branch Condition')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => nodeType = val);
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message Body / Prompt Text'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final key = keyController.text.trim();
                if (key.isEmpty || _activeFlow == null) return;

                final offset = _nodes.length * 50.0;
                final node = FlowNodeRow(
                  id: '',
                  flowId: _activeFlow!.id,
                  nodeKey: key,
                  nodeType: nodeType,
                  positionX: 100.0 + (offset % 300),
                  positionY: 80.0 + offset,
                  config: {'text': textController.text.trim()},
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await SupabaseService.saveFlowNode(node);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _openFlowCanvas(_activeFlow!);
              },
              child: const Text('Add Node'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_activeFlow != null) {
      return _buildCanvasView(isDark);
    }

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
                  Text('Visual Flows', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Interactive canvas flow builder for conversational WhatsApp bots',
                      style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateFlowDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Flow'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _flows.isEmpty
                    ? const Center(child: Text('No flows configured yet.'))
                    : ListView.separated(
                        itemCount: _flows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final flow = _flows[index];

                          return ListTile(
                            tileColor: isDark ? AppColors.darkCard : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.gitFork, color: AppColors.primary, size: 18),
                            ),
                            title: Text(flow.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Trigger: ${flow.triggerType} • Executions: ${flow.executionCount}'),
                            trailing: ElevatedButton(
                              onPressed: () => _openFlowCanvas(flow),
                              child: const Text('Open Canvas'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasView(bool isDark) {
    return Column(
      children: [
        // Canvas Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: isDark ? AppColors.darkCard : Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                onPressed: () => setState(() => _activeFlow = null),
              ),
              const SizedBox(width: 8),
              Text(_activeFlow!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddNodeDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Step Node'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Interactive Canvas Area with Grid
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF1F5F9),
            child: Stack(
              children: [
                if (_nodes.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.workflow, size: 40, color: AppColors.darkTextMuted),
                        const SizedBox(height: 12),
                        const Text('Interactive Flow Canvas', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Drag and drop conversational nodes to build interactive menus',
                            style: TextStyle(color: AppColors.darkTextMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddNodeDialog,
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add Start Node'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._nodes.map((node) {
                    final text = node.config['text'] as String?;
                    return Positioned(
                      left: node.positionX,
                      top: node.positionY,
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(node.nodeType.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const Icon(LucideIcons.move, size: 12, color: AppColors.darkTextMuted),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(node.nodeKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (text != null && text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(text, style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
