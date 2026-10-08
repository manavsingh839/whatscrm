import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../models/contact_models.dart';
import '../../../models/conversation_models.dart';
import '../../../models/pipeline_models.dart';
import '../../../models/whatsapp_models.dart';
import '../../../services/ai_service.dart';
import '../../../services/meta_api_service.dart';
import '../../../services/supabase_service.dart';

class InboxScreen extends StatefulWidget {
  final String? initialConversationId;

  const InboxScreen({super.key, this.initialConversationId});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Conversation> _conversations = [];
  Conversation? _selectedConversation;
  List<Message> _messages = [];
  List<Tag> _allTags = [];
  List<ContactNote> _contactNotes = [];
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isLoadingNotes = false;
  bool _showContactSidebar = true;
  String _searchQuery = '';
  ConversationStatus? _statusFilter;
  final String _agentFilter = 'all';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _noteController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  bool _isSending = false;
  bool _isGeneratingAiDraft = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingConversations = true);
    try {
      final tags = await SupabaseService.getTags();
      final convs = await SupabaseService.getConversations(
        status: _statusFilter,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        assignedAgentId: _agentFilter == 'all' ? null : _agentFilter,
      );

      setState(() {
        _allTags = tags;
        _conversations = convs;
        _isLoadingConversations = false;
      });

      if (convs.isNotEmpty) {
        if (widget.initialConversationId != null) {
          final target = convs.firstWhere(
            (c) => c.id == widget.initialConversationId,
            orElse: () => convs.first,
          );
          _selectConversation(target);
        } else if (_selectedConversation == null) {
          _selectConversation(convs.first);
        }
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _selectConversation(Conversation conv) async {
    setState(() {
      _selectedConversation = conv;
      _isLoadingMessages = true;
    });

    _setupRealtimeMessages(conv.id);
    _loadContactNotes(conv.contactId);

    try {
      final msgs = await SupabaseService.getMessages(conv.id);
      setState(() {
        _messages = msgs;
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoadingMessages = false);
    }
  }

  void _setupRealtimeMessages(String conversationId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = SupabaseService.subscribeMessages(conversationId).listen((data) {
      if (mounted && _selectedConversation?.id == conversationId) {
        setState(() {
          _messages = data.map((e) => Message.fromJson(e)).toList();
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadContactNotes(String contactId) async {
    setState(() => _isLoadingNotes = true);
    try {
      final notes = await SupabaseService.getContactNotes(contactId);
      if (mounted) {
        setState(() {
          _contactNotes = notes;
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contact notes: $e');
      if (mounted) setState(() => _isLoadingNotes = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage({
    String? customText,
    MessageContentType type = MessageContentType.text,
    String? mediaUrl,
    String? templateName,
    String templateLanguage = 'en',
  }) async {
    final text = (customText ?? _messageController.text).trim();
    if (text.isEmpty && type == MessageContentType.text && mediaUrl == null && templateName == null) {
      return;
    }
    final conv = _selectedConversation;
    if (conv == null) return;

    if (customText == null && type == MessageContentType.text) {
      _messageController.clear();
    }
    setState(() => _isSending = true);

    try {
      // 1. Create message in Supabase
      final newMsg = Message(
        id: '',
        conversationId: conv.id,
        senderType: SenderType.agent,
        contentType: type,
        contentText: text.isNotEmpty ? text : null,
        mediaUrl: mediaUrl,
        templateName: templateName,
        status: MessageStatus.sending,
        createdAt: DateTime.now(),
      );

      final inserted = await SupabaseService.insertMessage(newMsg);
      setState(() {
        _messages.add(inserted);
      });
      _scrollToBottom();

      // 2. Outbound WhatsApp send via Meta Cloud API if configured
      final waConfig = await SupabaseService.getWhatsAppConfig();
      if (waConfig != null && waConfig.isConnected && conv.contact != null) {
        try {
          String metaMsgId = '';
          if (type == MessageContentType.text) {
            metaMsgId = await MetaApiService.sendTextMessage(
              phoneNumberId: waConfig.phoneNumberId,
              accessToken: waConfig.accessToken,
              to: conv.contact!.phone,
              text: text,
            );
          } else if (mediaUrl != null) {
            metaMsgId = await MetaApiService.sendMediaMessage(
              phoneNumberId: waConfig.phoneNumberId,
              accessToken: waConfig.accessToken,
              to: conv.contact!.phone,
              mediaType: type.toDbValue(),
              mediaUrl: mediaUrl,
              caption: text.isNotEmpty ? text : null,
            );
          } else if (templateName != null) {
            metaMsgId = await MetaApiService.sendTemplateMessage(
              phoneNumberId: waConfig.phoneNumberId,
              accessToken: waConfig.accessToken,
              to: conv.contact!.phone,
              templateName: templateName,
              languageCode: templateLanguage,
            );
          }

          if (metaMsgId.isNotEmpty) {
            await SupabaseService.updateMessageStatus(inserted.id, MessageStatus.sent);
            if (mounted) {
              setState(() {
                final idx = _messages.indexWhere((m) => m.id == inserted.id);
                if (idx != -1) {
                  _messages[idx] = Message(
                    id: inserted.id,
                    conversationId: inserted.conversationId,
                    senderType: inserted.senderType,
                    contentType: inserted.contentType,
                    contentText: inserted.contentText,
                    mediaUrl: inserted.mediaUrl,
                    templateName: inserted.templateName,
                    status: MessageStatus.sent,
                    createdAt: inserted.createdAt,
                    messageId: metaMsgId,
                  );
                }
              });
            }
          }
        } catch (metaErr) {
          debugPrint('Meta send note: $metaErr');
          await SupabaseService.updateMessageStatus(inserted.id, MessageStatus.failed);
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == inserted.id);
              if (idx != -1) {
                _messages[idx] = Message(
                  id: inserted.id,
                  conversationId: inserted.conversationId,
                  senderType: inserted.senderType,
                  contentType: inserted.contentType,
                  contentText: inserted.contentText,
                  mediaUrl: inserted.mediaUrl,
                  templateName: inserted.templateName,
                  status: MessageStatus.failed,
                  createdAt: inserted.createdAt,
                  messageId: inserted.messageId,
                );
              }
            });

            final errStr = metaErr.toString();
            String userMsg = 'WhatsApp delivery failed: ${errStr.replaceAll("Exception: ", "")}';
            bool is24hWindow = errStr.contains('131047') || errStr.toLowerCase().contains('24 hour');
            if (is24hWindow) {
              userMsg = 'Customer service window closed (24 hours). You must use an approved Meta Template to initiate conversation.';
            } else if (errStr.contains('190') || errStr.contains('OAuthException')) {
              userMsg = 'Meta token invalid or expired. Please update your token in Settings → WhatsApp API.';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMsg),
                backgroundColor: AppColors.statusFailed,
                duration: const Duration(seconds: 5),
                action: is24hWindow
                    ? SnackBarAction(
                        label: 'Send Template',
                        textColor: Colors.white,
                        onPressed: _showTemplatesPicker,
                      )
                    : null,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Send error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleAiDraft() async {
    final conv = _selectedConversation;
    if (conv == null) return;

    setState(() => _isGeneratingAiDraft = true);
    try {
      final aiConfig = await SupabaseService.getAiConfig();
      if (aiConfig == null || aiConfig.apiKeyEncrypted == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please configure your AI API Key under Settings → AI Assistant')),
          );
        }
        return;
      }

      final draft = await AiService.generateDraftReply(
        config: aiConfig,
        apiKey: aiConfig.apiKeyEncrypted!,
        conversationHistory: _messages,
        contactName: conv.contact?.displayName,
      );

      if (draft.isNotEmpty && mounted) {
        setState(() {
          _messageController.text = draft;
        });
      }
    } catch (e) {
      debugPrint('AI draft error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Assistant note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAiDraft = false);
    }
  }

  void _showAttachMediaDialog() {
    final urlController = TextEditingController();
    final captionController = TextEditingController();
    MessageContentType selectedType = MessageContentType.image;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Media Attachment'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Media Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<MessageContentType>(
                  segments: const [
                    ButtonSegment(
                      value: MessageContentType.image,
                      label: Text('Image'),
                      icon: Icon(LucideIcons.image, size: 14),
                    ),
                    ButtonSegment(
                      value: MessageContentType.document,
                      label: Text('Doc'),
                      icon: Icon(LucideIcons.fileText, size: 14),
                    ),
                    ButtonSegment(
                      value: MessageContentType.audio,
                      label: Text('Audio'),
                      icon: Icon(LucideIcons.mic, size: 14),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) => setDialogState(() => selectedType = val.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Direct URL (https://...)',
                    hintText: 'https://example.com/file.jpg',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(labelText: 'Caption (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isEmpty) return;
                Navigator.of(ctx).pop();
                await _handleSendMessage(
                  customText: captionController.text.trim(),
                  type: selectedType,
                  mediaUrl: url,
                );
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickRepliesPicker() async {
    final quickReplies = await SupabaseService.getQuickReplies();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  tooltip: 'Create Quick Reply',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showAddQuickReplyDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (quickReplies.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No quick replies yet. Tap + to create one.',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: quickReplies.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final qr = quickReplies[idx];
                    return ListTile(
                      leading: const Icon(LucideIcons.zap, size: 18, color: AppColors.primary),
                      title: Text(qr.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(qr.contentText ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _messageController.text = qr.contentText ?? '';
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddQuickReplyDialog() {
    final shortcutController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Quick Reply'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shortcutController,
                decoration: const InputDecoration(
                  labelText: 'Shortcut (e.g. /greeting)',
                  hintText: '/hello',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message Content'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final shortcut = shortcutController.text.trim();
              final content = contentController.text.trim();
              if (shortcut.isEmpty || content.isEmpty) return;

              await SupabaseService.saveQuickReply(
                QuickReply(
                  id: '',
                  accountId: '',
                  userId: '',
                  title: shortcut,
                  kind: 'text',
                  contentText: content,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTemplatesPicker() async {
    final templates = await SupabaseService.getMessageTemplates();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 450,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approved WhatsApp Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (templates.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No templates synced yet. Go to Settings → Sync from Meta.',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final t = templates[idx];
                    return ListTile(
                      leading: const Icon(LucideIcons.layoutTemplate, size: 20, color: AppColors.whatsappGreen),
                      title: Text('${t.name} (${t.language})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(t.bodyText, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _handleSendMessage(
                            customText: t.bodyText,
                            type: MessageContentType.template,
                            templateName: t.name,
                            templateLanguage: t.language,
                          );
                        },
                        child: const Text('Send'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = _showContactSidebar && screenWidth >= 1200;

    return Row(
      children: [
        // 1. Conversations List (Left Pane)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildConversationSearchAndFilters(isDark),
                const Divider(height: 1),
                Expanded(child: _buildConversationList(isDark)),
              ],
            ),
          ),
        ),

        // 2. Chat Message Thread (Middle Pane)
        Expanded(
          child: _selectedConversation == null
              ? _buildEmptyState(isDark)
              : Column(
                  children: [
                    _buildChatHeader(isDark),
                    const Divider(height: 1),
                    Expanded(child: _buildMessageList(isDark)),
                    const Divider(height: 1),
                    _buildMessageComposer(isDark),
                  ],
                ),
        ),

        // 3. Contact Details Sidebar (Right Pane)
        if (showSidebar && _selectedConversation != null)
          SizedBox(
            width: 340,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  left: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: _buildContactSidebarContent(isDark),
            ),
          ),
      ],
    );
  }

  Widget _buildConversationSearchAndFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadInitialData();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.messageSquarePlus, size: 20, color: AppColors.primary),
                tooltip: 'Start New Chat',
                onPressed: _showStartNewChatDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', null),
                const SizedBox(width: 6),
                _buildStatusChip('Open', ConversationStatus.open),
                const SizedBox(width: 6),
                _buildStatusChip('Pending', ConversationStatus.pending),
                const SizedBox(width: 6),
                _buildStatusChip('Closed', ConversationStatus.closed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStartNewChatDialog() async {
    final contacts = await SupabaseService.getContacts(limit: 50);
    if (!mounted) return;

    final phoneController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: const Text('Start New Conversation'),
            content: SizedBox(
              width: 440,
              height: 380,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Select Contact'),
                      Tab(text: 'New Number'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        contacts.isEmpty
                            ? const Center(child: Text('No contacts found. Use "New Number" tab.'))
                            : ListView.separated(
                                itemCount: contacts.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final c = contacts[idx];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(c.displayName.substring(0, 1).toUpperCase()),
                                    ),
                                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(c.phone),
                                    onTap: () async {
                                      Navigator.of(ctx).pop();
                                      final conv = await SupabaseService.getOrCreateConversationForContact(c.id);
                                      if (conv != null && mounted) {
                                        await _loadInitialData();
                                        _selectConversation(conv);
                                      }
                                    },
                                  );
                                },
                              ),
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number (E.164, e.g. +919041434383)',
                                  prefixIcon: Icon(LucideIcons.phone, size: 18),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Name (Optional)',
                                  prefixIcon: Icon(LucideIcons.user, size: 18),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  final rawPhone = phoneController.text.trim();
                                  final phone = PhoneUtils.sanitizePhoneForMeta(rawPhone);
                                  if (phone.isEmpty) return;

                                  final name = nameController.text.trim();
                                  Navigator.of(ctx).pop();
                                  final newContact = await SupabaseService.createContact(
                                    phone: phone,
                                    name: name.isNotEmpty ? name : null,
                                  );
                                  final conv = await SupabaseService.getOrCreateConversationForContact(newContact.id);
                                  if (conv != null && mounted) {
                                    await _loadInitialData();
                                    _selectConversation(conv);
                                  }
                                },
                                child: const Text('Start Chat'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, ConversationStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = status);
        _loadInitialData();
      },
    );
  }

  Widget _buildConversationList(bool isDark) {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Text('No conversations found',
            style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13)),
      );
    }

    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final isSelected = _selectedConversation?.id == conv.id;

        return InkWell(
          onTap: () => _selectConversation(conv),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: isSelected
                ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    (conv.contact?.displayName.isNotEmpty ?? false)
                        ? conv.contact!.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              conv.contact?.displayName ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.lastMessageAt != null)
                            Text(
                              DateFormatter.formatRelative(conv.lastMessageAt!),
                              style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.lastMessageText ?? 'No messages yet',
                              style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatHeader(bool isDark) {
    final conv = _selectedConversation;
    if (conv == null) return const SizedBox.shrink();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              (conv.contact?.displayName.isNotEmpty ?? false) ? conv.contact!.displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.contact?.displayName ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  conv.contact?.phone ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                ),
              ],
            ),
          ),
          // Status Selector
          DropdownButton<ConversationStatus>(
            value: conv.status,
            underline: const SizedBox.shrink(),
            items: ConversationStatus.values.map((s) {
              return DropdownMenuItem(
                value: s,
                child: Text(s.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (newStatus) async {
              if (newStatus != null) {
                await SupabaseService.updateConversationStatus(conv.id, newStatus);
                setState(() {
                  _selectedConversation = conv.copyWith(status: newStatus);
                });
                _loadInitialData();
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _showContactSidebar ? LucideIcons.panelRightClose : LucideIcons.panelRightOpen,
              size: 20,
            ),
            tooltip: 'Toggle Details Sidebar',
            onPressed: () => setState(() => _showContactSidebar = !_showContactSidebar),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages in this conversation yet.',
            style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg.isOutbound;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
                  : (isDark ? AppColors.darkSurface : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 12),
              ),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.aiGenerated) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('AI Generated', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (msg.templateName != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.whatsappGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Template: ${msg.templateName}',
                      style: const TextStyle(fontSize: 10, color: AppColors.whatsappGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) ...[
                  if (msg.contentType == MessageContentType.image)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        msg.mediaUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(LucideIcons.image, size: 48),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.paperclip, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            msg.mediaUrl!,
                            style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                ],
                if (msg.contentText != null && msg.contentText!.isNotEmpty)
                  Text(
                    msg.contentText!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMe && !isDark ? Colors.black87 : (isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormatter.formatTime(msg.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildMessageStatusIcon(msg.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(LucideIcons.clock, size: 12, color: AppColors.darkTextMuted);
      case MessageStatus.sent:
        return const Icon(LucideIcons.check, size: 12, color: AppColors.darkTextMuted);
      case MessageStatus.delivered:
        return const Icon(LucideIcons.checkCheck, size: 12, color: AppColors.darkTextMuted);
      case MessageStatus.read:
        return const Icon(LucideIcons.checkCheck, size: 12, color: Color(0xFF34B7F1));
      case MessageStatus.failed:
        return const Icon(LucideIcons.alertCircle, size: 12, color: AppColors.statusFailed);
    }
  }

  Widget _buildMessageComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: _isGeneratingAiDraft
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
            tooltip: 'Draft AI Reply',
            onPressed: _isGeneratingAiDraft ? null : _handleAiDraft,
          ),
          IconButton(
            icon: const Icon(LucideIcons.paperclip, size: 18),
            tooltip: 'Attach Media',
            onPressed: _showAttachMediaDialog,
          ),
          IconButton(
            icon: const Icon(LucideIcons.zap, size: 18, color: AppColors.primary),
            tooltip: 'Quick Replies',
            onPressed: _showQuickRepliesPicker,
          ),
          IconButton(
            icon: const Icon(LucideIcons.layoutTemplate, size: 18, color: AppColors.whatsappGreen),
            tooltip: 'WhatsApp Templates',
            onPressed: _showTemplatesPicker,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Type a message... (Enter to send)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.send, size: 18, color: AppColors.primary),
            onPressed: _isSending ? null : () => _handleSendMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSidebarContent(bool isDark) {
    final contact = _selectedConversation?.contact;
    if (contact == null) {
      return const Center(child: Text('Contact info not available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(contact.phone, style: const TextStyle(color: AppColors.darkTextMuted, fontSize: 12)),
              if (contact.email != null && contact.email!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(contact.email!, style: const TextStyle(color: AppColors.darkTextMuted, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Tags Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 16),
              onPressed: () => _showAddTagDialog(contact.id),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: contact.tags.map((t) {
            return Chip(
              label: Text(t.name, style: const TextStyle(fontSize: 11)),
              backgroundColor: Color(int.parse(t.color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.15),
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Quick Deal Creation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Deals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 16),
              onPressed: () => _showCreateDealDialog(contact),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Contact Notes Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Internal Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 16),
              tooltip: 'Add Note',
              onPressed: () => _showAddNoteDialog(contact.id),
            ),
          ],
        ),
        if (_isLoadingNotes)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_contactNotes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No notes yet for this contact.', style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
          )
        else
          Column(
            children: _contactNotes.map((n) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.noteText, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.formatRelative(n.createdAt),
                            style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 14, color: AppColors.statusFailed),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await SupabaseService.deleteContactNote(n.id);
                        _loadContactNotes(contact.id);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAddNoteDialog(String contactId) {
    _noteController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Internal Note'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter internal notes about this contact...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = _noteController.text.trim();
              if (text.isEmpty) return;
              await SupabaseService.addContactNote(contactId, text);
              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadContactNotes(contactId);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(String contactId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _allTags.map((tag) {
            return ListTile(
              title: Text(tag.name),
              onTap: () async {
                await SupabaseService.assignTagToContact(contactId, tag.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadInitialData();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCreateDealDialog(Contact contact) {
    final titleController = TextEditingController(text: 'Deal with ${contact.displayName}');
    final valueController = TextEditingController(text: '1000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Deal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Deal Title')),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Value (USD)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = SupabaseService.currentUser;
              final pipelines = await SupabaseService.getPipelines();
              if (pipelines.isNotEmpty) {
                final stages = await SupabaseService.getPipelineStages(pipelines.first.id);
                if (stages.isNotEmpty) {
                  await SupabaseService.createDeal(
                    Deal(
                      id: '',
                      userId: user?.id ?? '',
                      pipelineId: pipelines.first.id,
                      stageId: stages.first.id,
                      contactId: contact.id,
                      conversationId: _selectedConversation?.id,
                      title: titleController.text.trim(),
                      value: double.tryParse(valueController.text.trim()) ?? 0.0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                }
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.messageSquare, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Select a conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Choose a thread from the list to view messages and reply',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
        ],
      ),
    );
  }
}
