import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class WebhooksScreen extends StatefulWidget {
  const WebhooksScreen({super.key});

  @override
  State<WebhooksScreen> createState() => _WebhooksScreenState();
}

class _WebhooksScreenState extends State<WebhooksScreen> {
  final _webhookUrlController = TextEditingController(
    text: 'http://localhost:3000/api/whatsapp/webhook',
  );
  final _verifyTokenController = TextEditingController(
    text: 'wacrm_verify_token_secure',
  );

  // Simulation Controllers
  final _simPhoneController = TextEditingController(text: '919914649789');
  final _simNameController = TextEditingController(text: 'Manav (Test Lead)');
  final _simMessageController = TextEditingController(
    text: 'Hello! Testing WhatsApp Webhook inbound message to CRM Inbox.',
  );

  String _serverStatus = 'checking'; // 'checking' | 'online' | 'offline'
  String? _statusDetail;
  bool _isTestingPing = false;
  bool _isSimulatingInbound = false;
  final List<String> _diagnosticLogs = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _verifyTokenController.dispose();
    _simPhoneController.dispose();
    _simNameController.dispose();
    _simMessageController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('webhook_custom_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _webhookUrlController.text = savedUrl;
      }

      if (SupabaseConfig.isConfigured) {
        final wa = await SupabaseService.getWhatsAppConfig();
        if (wa != null && wa.verifyToken != null && wa.verifyToken!.isNotEmpty) {
          if (!wa.verifyToken!.contains(':')) {
            _verifyTokenController.text = wa.verifyToken!;
          }
        }
      }
    } catch (e) {
      debugPrint('Note: Webhook config loading: $e');
    }

    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    setState(() {
      _serverStatus = 'checking';
      _statusDetail = 'Checking server health...';
    });

    try {
      final inputUri = Uri.tryParse(_webhookUrlController.text.trim());
      final host = inputUri?.host ?? 'localhost';
      final port = inputUri?.hasPort == true ? inputUri!.port : 3000;
      final scheme = inputUri?.scheme.isNotEmpty == true ? inputUri!.scheme : 'http';
      final healthUri = Uri.parse('$scheme://$host:$port/health');

      final res = await http.get(healthUri).timeout(const Duration(seconds: 3));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _serverStatus = 'online';
          _statusDetail = 'Webhook server is LIVE and responding on $scheme://$host:$port';
        });
        _addLog('✅ [HEALTH CHECK] Server is online (Status 200 OK)');
      } else {
        setState(() {
          _serverStatus = 'offline';
          _statusDetail = 'Server responded with HTTP ${res.statusCode}';
        });
        _addLog('⚠️ [HEALTH CHECK] HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverStatus = 'offline';
        _statusDetail = 'Could not reach server. Run: node server/webhook_server.js';
      });
      _addLog('⚠️ [HEALTH CHECK] Connection note: $e');
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _diagnosticLogs.insert(0, '[$timestamp] $msg');
      if (_diagnosticLogs.length > 20) {
        _diagnosticLogs.removeLast();
      }
    });
  }

  Future<void> _saveWebhookUrl() async {
    final url = _webhookUrlController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhook_custom_url', url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Webhook URL saved locally!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
    _checkServerHealth();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testMetaPing() async {
    setState(() => _isTestingPing = true);
    final targetUrl = _webhookUrlController.text.trim();
    final token = _verifyTokenController.text.trim();
    const challengeCode = 'wacrm_challenge_test_success_999';

    try {
      final uri = Uri.parse(
        '$targetUrl?hub.mode=subscribe&hub.verify_token=${Uri.encodeComponent(token)}&hub.challenge=$challengeCode',
      );

      _addLog('📡 Sending Meta Verification Challenge GET -> $targetUrl');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.body == challengeCode) {
        _addLog('🎉 [VERIFICATION SUCCESS] Meta Challenge accepted! (200 OK)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Verification Challenge PASSED! Meta will accept this webhook.'),
              backgroundColor: AppColors.whatsappGreen,
            ),
          );
        }
      } else {
        _addLog('❌ [VERIFICATION FAILED] Status: ${res.statusCode}, Body: ${res.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: HTTP ${res.statusCode} - ${res.body}'),
              backgroundColor: AppColors.statusFailed,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('❌ [ERROR] Verification Ping failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingPing = false);
    }
  }

  Future<void> _simulateInboundMessage() async {
    setState(() => _isSimulatingInbound = true);
    final targetUrl = _webhookUrlController.text.trim();
    final phone = _simPhoneController.text.trim().replaceAll('+', '');
    final name = _simNameController.text.trim();
    final messageText = _simMessageController.text.trim();

    if (phone.isEmpty || messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number and message text cannot be empty.')),
      );
      setState(() => _isSimulatingInbound = false);
      return;
    }

    final payload = {
      'object': 'whatsapp_business_account',
      'entry': [
        {
          'id': '1772056763874215',
          'changes': [
            {
              'value': {
                'messaging_product': 'whatsapp',
                'metadata': {
                  'display_phone_number': '919041434383',
                  'phone_number_id': '1443849712136092',
                },
                'contacts': [
                  {
                    'profile': {'name': name},
                    'wa_id': phone,
                  }
                ],
                'messages': [
                  {
                    'from': phone,
                    'id': 'wamid.TEST_${DateTime.now().millisecondsSinceEpoch}',
                    'timestamp': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
                    'text': {'body': messageText},
                    'type': 'text',
                  }
                ],
              },
              'field': 'messages',
            }
          ],
        }
      ],
    };

    try {
      _addLog('📩 Simulating Meta Inbound POST from +$phone ($name)...');
      final res = await http
          .post(
            Uri.parse(targetUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        _addLog('✨ [SUCCESS] Webhook accepted message! Synced to Supabase database.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Incoming message synced! Check Inbox to view.'),
              backgroundColor: AppColors.whatsappGreen,
              action: SnackBarAction(
                label: 'Open Inbox',
                textColor: Colors.white,
                onPressed: () => context.go('/inbox'),
              ),
            ),
          );
        }
      } else {
        _addLog('⚠️ [FAILED] Server returned status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      _addLog('❌ [ERROR] Simulation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulation error: $e'), backgroundColor: AppColors.statusFailed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulatingInbound = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),

          _buildServerStatusBanner(isDark),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildCredentialsCard(isDark),
                          const SizedBox(height: 24),
                          _buildSimulationCard(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildMetaInstructionsCard(isDark),
                          const SizedBox(height: 24),
                          _buildDiagnosticsLogCard(isDark),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildCredentialsCard(isDark),
                    const SizedBox(height: 24),
                    _buildSimulationCard(isDark),
                    const SizedBox(height: 24),
                    _buildMetaInstructionsCard(isDark),
                    const SizedBox(height: 24),
                    _buildDiagnosticsLogCard(isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.webhook, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Webhooks & Real-time Integration',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Connect WhatsApp Cloud API to receive live customer replies and message status receipts',
                style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerStatusBanner(bool isDark) {
    final isOnline = _serverStatus == 'online';
    final isChecking = _serverStatus == 'checking';

    final Color bgColor = isOnline
        ? AppColors.whatsappGreen.withValues(alpha: 0.12)
        : (isChecking
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.statusFailed.withValues(alpha: 0.12));

    final Color borderColor = isOnline
        ? AppColors.whatsappGreen.withValues(alpha: 0.3)
        : (isChecking
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.statusFailed.withValues(alpha: 0.3));

    final Color textColor = isOnline
        ? AppColors.whatsappGreen
        : (isChecking ? AppColors.primary : AppColors.statusFailed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOnline
                        ? LucideIcons.checkCircle2
                        : (isChecking ? LucideIcons.loader2 : LucideIcons.alertCircle),
                    color: textColor,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline
                              ? 'Local Webhook Server Active (Port 3000)'
                              : (isChecking ? 'Checking Server Status...' : 'Webhook Server Not Detected'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusDetail ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _checkServerHealth,
                      icon: const Icon(LucideIcons.refreshCw, size: 14),
                      label: const Text('Refresh Status'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: borderColor),
                      ),
                    ),
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _checkServerHealth,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Refresh Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCredentialsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.key, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Meta Webhook Setup Credentials',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isTestingPing ? null : _testMetaPing,
                icon: _isTestingPing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.activity, size: 14),
                label: const Text('Test Verification Ping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Copy these exact credentials into Meta Developers Console → WhatsApp → Configuration → Webhook.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: 20),

          // Callback URL field
          const Text('Callback URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _webhookUrlController,
                  decoration: InputDecoration(
                    hintText: 'https://your-public-url.ngrok-free.app/api/whatsapp/webhook',
                    suffixIcon: IconButton(
                      icon: const Icon(LucideIcons.save, size: 16),
                      tooltip: 'Save custom URL',
                      onPressed: _saveWebhookUrl,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(_webhookUrlController.text, 'Callback URL'),
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '💡 Note: Meta requires an HTTPS URL. For local development, run a tunnel like ngrok or localtunnel.',
            style: TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: 18),

          // Verify Token field
          const Text('Verify Token', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _verifyTokenController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: 'wacrm_verify_token_secure',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(_verifyTokenController.text, 'Verify Token'),
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Required Webhook Subscriptions
          const Text('Required Webhook Field Subscriptions',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge('messages', 'Required (Incoming Chats)', AppColors.whatsappGreen),
              _buildBadge('message_deliveries', 'Optional (Status Ticks)', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '• $subtitle',
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.flaskConical, size: 18, color: AppColors.whatsappGreen),
                  SizedBox(width: 8),
                  Text(
                    'Simulate Incoming WhatsApp Message',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSimulatingInbound ? null : _simulateInboundMessage,
                icon: _isSimulatingInbound
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.send, size: 14),
                label: const Text('Send Simulated Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsappGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Test the full inbound flow: this fires a simulated Meta webhook payload to your server, creating the contact & message in Supabase so it shows in the CRM Inbox.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _simPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Sender Phone Number',
                    hintText: '919914649789',
                    prefixText: '+',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _simNameController,
                  decoration: const InputDecoration(
                    labelText: 'Sender Name',
                    hintText: 'Customer Name',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _simMessageController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Message Body',
              hintText: 'Enter incoming message text...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInstructionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.helpCircle, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Meta Developer Console Setup Guide',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildStepRow('1', 'Go to developers.facebook.com and open your WhatsApp App.'),
          _buildStepRow('2', 'In the left sidebar, click WhatsApp → Configuration.'),
          _buildStepRow('3', 'Locate the Webhook section and click the Edit button.'),
          _buildStepRow(
            '4',
            'Paste your public Callback URL (HTTPS) and Verify Token (wacrm_verify_token_secure).',
          ),
          _buildStepRow('5', 'Click Verify and Save.'),
          _buildStepRow('6', 'Under Webhook fields, click Manage and Subscribe to "messages".'),

          const Divider(height: 28),
          const Text('Run Local Tunnel Commands:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),

          _buildCommandBox('npx localtunnel --port 3000', 'Localtunnel (Free, Fast)'),
          const SizedBox(height: 8),
          _buildCommandBox('ngrok http 3000', 'Ngrok Tunnel'),
          const SizedBox(height: 8),
          _buildCommandBox('node server/webhook_server.js', 'Start Webhook Server'),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandBox(String command, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted)),
                const SizedBox(height: 2),
                Text(
                  command,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.whatsappGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 14, color: AppColors.darkTextMuted),
            tooltip: 'Copy command',
            onPressed: () => _copyToClipboard(command, label),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsLogCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.terminal, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Live Webhook Diagnostics Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_diagnosticLogs.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _diagnosticLogs.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: _diagnosticLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No events logged yet.\nClick "Test Verification Ping" or "Send Simulated Message" above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.darkTextMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _diagnosticLogs.length,
                    itemBuilder: (context, idx) {
                      final log = _diagnosticLogs[idx];
                      Color logColor = Colors.white70;
                      if (log.contains('✅') || log.contains('🎉') || log.contains('✨')) {
                        logColor = AppColors.whatsappGreen;
                      } else if (log.contains('❌') || log.contains('⚠️')) {
                        logColor = AppColors.statusFailed;
                      } else if (log.contains('📡') || log.contains('📩')) {
                        logColor = Colors.lightBlueAccent;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: logColor,
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
}
