import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/whatsapp_models.dart';
import '../../../models/settings_models.dart';
import '../../../models/contact_models.dart';
import '../../../services/meta_api_service.dart';
import '../../../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // WhatsApp Config Controllers
  final _phoneIdController = TextEditingController();
  final _wabaIdController = TextEditingController();
  final _tokenController = TextEditingController();
  final _verifyTokenController = TextEditingController();
  bool _isSavingWa = false;
  bool _isTestingWa = false;
  bool _obscureToken = true;
  String? _waStatusMessage;

  // AI Config Controllers
  final _aiKeyController = TextEditingController();
  final _aiPromptController = TextEditingController();
  String _aiProvider = 'openai';
  String _aiModel = 'gpt-4o-mini';
  double _aiTemperature = 0.7;

  // Supabase Config Controllers
  final _supabaseUrlController = TextEditingController(text: SupabaseConfig.url);
  final _supabaseKeyController = TextEditingController(text: SupabaseConfig.anonKey);

  List<MessageTemplate> _templates = [];
  List<QuickReply> _quickReplies = [];
  List<Tag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final wa = await SupabaseService.getWhatsAppConfig();
      if (wa != null) {
        _phoneIdController.text = wa.phoneNumberId;
        _wabaIdController.text = wa.wabaId ?? '';
        
        // Handle token: if it contains colon, it was encrypted in old Next.js
        if (wa.accessToken.contains(':')) {
          _tokenController.text = '';
          _waStatusMessage = 'Notice: Old encrypted token detected in database. Please paste your raw Meta Permanent Access Token (starts with EAA...) and click Save Credentials.';
        } else {
          _tokenController.text = wa.accessToken;
        }

        // Clean verify token
        if (wa.verifyToken != null && wa.verifyToken!.contains(':')) {
          _verifyTokenController.text = 'wacrm_verify_token_secure';
        } else {
          _verifyTokenController.text = wa.verifyToken ?? 'wacrm_verify_token_secure';
        }
      }

      final ai = await SupabaseService.getAiConfig();
      if (ai != null) {
        _aiProvider = ai.provider;
        _aiModel = ai.model;
        _aiKeyController.text = ai.apiKeyEncrypted ?? '';
        _aiPromptController.text = ai.systemPrompt;
        _aiTemperature = ai.temperature;
      }

      final templates = await SupabaseService.getMessageTemplates();
      final qReplies = await SupabaseService.getQuickReplies();
      final tags = await SupabaseService.getTags();

      setState(() {
        _templates = templates;
        _quickReplies = qReplies;
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWhatsAppConfig() async {
    final phoneId = _phoneIdController.text.trim();
    final token = _tokenController.text.trim();

    if (phoneId.isEmpty || token.isEmpty) {
      setState(() => _waStatusMessage = 'Phone Number ID and Access Token are required.');
      return;
    }

    if (token.contains(':')) {
      setState(() => _waStatusMessage = 'The token contains colons (encrypted hash). Please paste your raw Meta Access Token starting with "EAA...".');
      return;
    }

    setState(() {
      _isSavingWa = true;
      _waStatusMessage = null;
    });

    try {
      final user = SupabaseService.currentUser;
      final config = WhatsAppConfig(
        id: '',
        userId: user?.id ?? '',
        phoneNumberId: phoneId,
        wabaId: _wabaIdController.text.trim(),
        accessToken: token,
        verifyToken: _verifyTokenController.text.trim(),
        status: 'connected',
        connectedAt: DateTime.now(),
      );

      await SupabaseService.saveWhatsAppConfig(config);
      if (mounted) {
        setState(() {
          _waStatusMessage = 'WhatsApp credentials saved successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp credentials saved successfully!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      setState(() => _waStatusMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSavingWa = false);
    }
  }

  Future<void> _testWhatsAppConnection() async {
    final phoneId = _phoneIdController.text.trim();
    final token = _tokenController.text.trim();

    if (phoneId.isEmpty) {
      setState(() => _waStatusMessage = 'Please enter your Meta Phone Number ID.');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(phoneId)) {
      setState(() => _waStatusMessage = 'Phone Number ID must be numbers only. Copy it from Meta App Dashboard → WhatsApp → API Setup.');
      return;
    }
    if (token.isEmpty) {
      setState(() => _waStatusMessage = 'Please enter your Meta Permanent Access Token.');
      return;
    }
    if (token.contains(':')) {
      setState(() => _waStatusMessage = 'The token entered is an encrypted hash from old Next.js. Please paste your raw Meta Permanent Access Token starting with "EAA...".');
      return;
    }

    setState(() {
      _isTestingWa = true;
      _waStatusMessage = null;
    });

    try {
      final phoneInfo = await MetaApiService.verifyPhoneNumber(
        phoneNumberId: phoneId,
        accessToken: token,
      );
      setState(() {
        _waStatusMessage = 'Connected Successfully!\n• Business: ${phoneInfo['verified_name'] ?? 'Verified'}\n• Phone: ${phoneInfo['display_phone_number']}\n• Quality: ${phoneInfo['quality_rating'] ?? 'GREEN'}';
      });
    } catch (e) {
      setState(() {
        _waStatusMessage = 'Connection failed: $e';
      });
    } finally {
      if (mounted) setState(() => _isTestingWa = false);
    }
  }

  Future<void> _syncTemplates() async {
    final wabaId = _wabaIdController.text.trim();
    final token = _tokenController.text.trim();
    final user = SupabaseService.currentUser;

    if (wabaId.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save WABA ID and Access Token first.')),
      );
      return;
    }

    try {
      final fetched = await MetaApiService.fetchWabaTemplates(
        wabaId: wabaId,
        accessToken: token,
        userId: user?.id ?? '',
      );
      for (final t in fetched) {
        await SupabaseService.saveMessageTemplate(t);
      }
      _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced ${fetched.length} templates from Meta!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync templates: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Configure WhatsApp API, AI Assistant, templates, tags, and backend connection',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
          const SizedBox(height: 16),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(LucideIcons.messageCircle, size: 16), text: 'WhatsApp API'),
              Tab(icon: Icon(LucideIcons.sparkles, size: 16), text: 'AI Assistant'),
              Tab(icon: Icon(LucideIcons.layoutTemplate, size: 16), text: 'Templates'),
              Tab(icon: Icon(LucideIcons.tags, size: 16), text: 'Tags & Fields'),
              Tab(icon: Icon(LucideIcons.database, size: 16), text: 'Supabase Server'),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWhatsAppTab(isDark),
                      _buildAiTab(isDark),
                      _buildTemplatesTab(isDark),
                      _buildTagsTab(isDark),
                      _buildSupabaseTab(isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppTab(bool isDark) {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WhatsApp Business Cloud API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Enter credentials from your Meta Developers App Dashboard',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
            const SizedBox(height: 20),

            if (_waStatusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _waStatusMessage!.contains('Connected')
                      ? AppColors.whatsappGreen.withValues(alpha: 0.15)
                      : AppColors.statusFailed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _waStatusMessage!,
                  style: TextStyle(
                    color: _waStatusMessage!.contains('Connected')
                        ? AppColors.whatsappGreen
                        : AppColors.statusFailed,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _phoneIdController,
              decoration: const InputDecoration(labelText: 'Phone Number ID'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wabaIdController,
              decoration: const InputDecoration(labelText: 'WhatsApp Business Account ID (WABA ID)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenController,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: 'Permanent System User Access Token',
                hintText: 'Starts with EAA...',
                suffixIcon: IconButton(
                  icon: Icon(_obscureToken ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                  onPressed: () => setState(() => _obscureToken = !_obscureToken),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _verifyTokenController,
              decoration: const InputDecoration(labelText: 'Webhook Verify Token (arbitrary secret string)'),
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _isSavingWa ? null : _saveWhatsAppConfig,
                  child: _isSavingWa
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Credentials'),
                ),
                OutlinedButton(
                  onPressed: _isTestingWa ? null : _testWhatsAppConnection,
                  child: _isTestingWa
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test Connection'),
                ),
                ElevatedButton.icon(
                  onPressed: _syncTemplates,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Sync Templates'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whatsappGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.webhook, color: AppColors.primary, size: 26),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Incoming Webhooks',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure Meta Webhooks with your Callback URL and Verify Token to receive live incoming messages and delivery receipts in your Inbox.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/webhooks'),
                    icon: const Icon(LucideIcons.arrowRight, size: 14),
                    label: const Text('Configure Webhooks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Where to get these credentials?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 8),
                  Text('1. Go to developers.facebook.com → My Apps → WhatsApp → API Setup.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('2. Copy Phone Number ID and WhatsApp Business Account ID (numeric digits only).', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('3. Under Business Settings → System Users, generate a Permanent Access Token with whatsapp_business_management and whatsapp_business_messaging permissions.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiTab(bool isDark) {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Reply Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Bring your own OpenAI or Anthropic API key to enable 1-click AI drafts & auto-replies',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _aiProvider,
                    items: const [
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(value: 'anthropic', child: Text('Anthropic')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _aiProvider = val);
                    },
                    decoration: const InputDecoration(labelText: 'Provider'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _aiModel),
                    onChanged: (v) => _aiModel = v,
                    decoration: const InputDecoration(labelText: 'Model (e.g. gpt-4o-mini)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _aiKeyController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _aiPromptController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'System Prompt & Persona'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final user = SupabaseService.currentUser;
                final cfg = AiConfig(
                  id: '',
                  accountId: user?.id ?? '',
                  provider: _aiProvider,
                  model: _aiModel,
                  apiKeyEncrypted: _aiKeyController.text.trim(),
                  systemPrompt: _aiPromptController.text.trim(),
                  temperature: _aiTemperature,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await SupabaseService.saveAiConfig(cfg);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI Assistant configuration saved!'), backgroundColor: AppColors.primary),
                  );
                }
              },
              child: const Text('Save AI Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_templates.length} Meta Templates Synced', style: const TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _syncTemplates,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Sync from Meta'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _templates.isEmpty
              ? const Center(child: Text('No templates synced yet. Click "Sync from Meta" to import.'))
              : ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    return ListTile(
                      tileColor: isDark ? AppColors.darkCard : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${t.category} • Language: ${t.language}\n${t.bodyText}', maxLines: 2),
                      trailing: Chip(
                        label: Text(t.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: t.isApproved
                            ? AppColors.whatsappGreen.withValues(alpha: 0.15)
                            : AppColors.statusPending.withValues(alpha: 0.15),
                        side: BorderSide.none,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTagsTab(bool isDark) {
    final tagController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagController,
                decoration: const InputDecoration(hintText: 'New tag name...'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                final name = tagController.text.trim();
                if (name.isNotEmpty) {
                  await SupabaseService.createTag(name);
                  tagController.clear();
                  _loadSettings();
                }
              },
              child: const Text('Add Tag'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((t) {
            return Chip(
              label: Text(t.name),
              backgroundColor: Color(int.parse(t.color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.2),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('Quick Replies (${_quickReplies.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_quickReplies.isEmpty)
          const Text('No quick replies created yet.', style: TextStyle(color: AppColors.darkTextMuted, fontSize: 12))
        else
          ..._quickReplies.map((qr) => ListTile(
                title: Text(qr.title),
                subtitle: Text(qr.contentText ?? 'Interactive payload'),
              )),
      ],
    );
  }

  Widget _buildSupabaseTab(bool isDark) {
    final webhookUrl = '${_supabaseUrlController.text.trim()}/functions/v1/whatsapp-webhook';
    final verifyToken = _verifyTokenController.text.trim().isNotEmpty
        ? _verifyTokenController.text.trim()
        : 'wacrm_verify_token_secure';

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supabase Backend Endpoint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Connect this Flutter CRM to your Supabase project (self-hosted or cloud)',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
            const SizedBox(height: 20),
            TextField(
              controller: _supabaseUrlController,
              decoration: const InputDecoration(labelText: 'Supabase URL (e.g. https://xyz.supabase.co)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _supabaseKeyController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Supabase Anon Public Key'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await SupabaseConfig.saveConfig(
                  url: _supabaseUrlController.text.trim(),
                  anonKey: _supabaseKeyController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supabase configuration saved!'), backgroundColor: AppColors.primary),
                  );
                }
              },
              child: const Text('Save & Apply Endpoint'),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            const Text('Meta Webhook Integration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Configure this in Meta Developer Portal to receive WhatsApp messages in real-time',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
            const SizedBox(height: 16),

            // Callback URL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Callback URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          webhookUrl,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 16),
                        tooltip: 'Copy URL',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: webhookUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Webhook URL copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Verify Token
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Verify Token', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          verifyToken,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 16),
                        tooltip: 'Copy Token',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: verifyToken));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Verify Token copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('How to configure in Meta Portal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  SizedBox(height: 6),
                  Text('1. Go to developers.facebook.com → My Apps → WhatsApp → Configuration.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('2. In Webhook section, click "Edit" and paste Callback URL and Verify Token above.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('3. Click "Verify and Save".', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('4. Click "Manage Webhook fields" and subscribe to the "messages" event.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
