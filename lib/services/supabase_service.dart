import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/supabase_config.dart';
import '../models/account_models.dart';
import '../models/automation_models.dart';
import '../models/broadcast_models.dart';
import '../models/contact_models.dart';
import '../models/conversation_models.dart';
import '../models/flow_models.dart';
import '../models/notification_models.dart';
import '../models/pipeline_models.dart';
import '../models/settings_models.dart';
import '../models/whatsapp_models.dart';

class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;
  static const _uuid = Uuid();

  // Fallback IDs for demo mode if unauthenticated
  static const String fallbackAccountId = '8539e831-05bd-4118-9af0-d2a7a76d8c23';
  static const String fallbackUserId = '1ab684fd-bb0c-4ec8-818d-3baf9ab6af53';

  // ============================================================
  // AUTH CONTEXT HELPER
  // ============================================================

  static Future<Map<String, String>> getAuthContext() async {
    if (currentUser == null) {
      try {
        await signInWithEmail(
          email: 'wacrm.admin@gmail.com',
          password: 'password123456',
        );
      } catch (e) {
        debugPrint('Auto-auth notice in getAuthContext: $e');
      }
    }

    final user = currentUser;
    String? accountId;
    String? userId = user?.id;

    if (user != null) {
      try {
        final profile = await getCurrentProfile();
        accountId = profile?.accountId;
      } catch (_) {}
    }

    return {
      'user_id': userId ?? fallbackUserId,
      'account_id': accountId ?? fallbackAccountId,
    };
  }

  // ============================================================
  // AUTH & PROFILE
  // ============================================================

  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  static Future<void> resetPasswordForEmail(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<Profile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) {
      try {
        final res = await client.from('profiles').select().limit(1).maybeSingle();
        if (res != null) return Profile.fromJson(res);
      } catch (_) {}
      return null;
    }

    final response = await client
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  static Future<void> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final updates = {
      'full_name': fullName,
      // ignore: use_null_aware_elements
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await client.from('profiles').update(updates).eq('user_id', user.id);
  }

  // ============================================================
  // ACCOUNTS & TEAM MEMBERS
  // ============================================================

  static Future<List<AccountMember>> getAccountMembers() async {
    try {
      final response = await client.rpc('get_account_members');
      if (response is List) {
        return response
            .map((e) => AccountMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      try {
        final response = await client.from('profiles').select();
        return (response as List)
            .map((e) => AccountMember(
                  userId: e['user_id'] ?? '',
                  fullName: e['full_name'] ?? '',
                  email: e['email'],
                  avatarUrl: e['avatar_url'],
                  role: AccountRole.fromString(e['account_role']),
                  joinedAt: DateTime.tryParse(e['created_at'] ?? '') ?? DateTime.now(),
                ))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<String> createAccountInvitation({required String role, String? label}) async {
    final ctx = await getAuthContext();
    final rawToken = _uuid.v4().replaceAll('-', '');
    final tokenBytes = utf8.encode(rawToken);
    final tokenHash = crypto.sha256.convert(tokenBytes).toString();

    await client.from('account_invitations').insert({
      'account_id': ctx['account_id'],
      'token_hash': tokenHash,
      'role': role.toLowerCase(),
      if (label != null && label.isNotEmpty) 'label': label,
      'created_by_user_id': ctx['user_id'],
      'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    return rawToken;
  }

  static Future<void> updateMemberRole(String userId, String role) async {
    await client.from('profiles').update({
      'account_role': role.toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  static Future<void> removeMember(String userId) async {
    await client.from('profiles').update({
      'account_id': null,
      'account_role': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  static Future<void> touchPresence() async {
    try {
      await client.rpc('touch_presence');
    } catch (e) {
      debugPrint('touch_presence error: $e');
    }
  }

  // ============================================================
  // CONTACTS & TAGS
  // ============================================================

  static Future<List<Contact>> getContacts({
    String? searchQuery,
    String? tagId,
    int limit = 100,
  }) async {
    var query = client.from('contacts').select('''
      *,
      contact_tags (
        tags (*)
      )
    ''');

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or('name.ilike.%$q%,phone.ilike.%$q%,company.ilike.%$q%');
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return (response as List)
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Contact> createContact({
    required String phone,
    String? name,
    String? email,
    String? company,
    List<String> tagIds = const [],
  }) async {
    final ctx = await getAuthContext();

    final insertData = {
      'user_id': ctx['user_id'],
      'account_id': ctx['account_id'],
      'phone': phone,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (company != null && company.isNotEmpty) 'company': company,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await client
        .from('contacts')
        .insert(insertData)
        .select()
        .single();

    final contact = Contact.fromJson(response);

    if (tagIds.isNotEmpty) {
      for (final tId in tagIds) {
        await client.from('contact_tags').insert({
          'contact_id': contact.id,
          'tag_id': tId,
        });
      }
    }

    return contact;
  }

  static Future<void> updateContact(Contact contact) async {
    final data = contact.toJson();
    data.remove('id');
    await client
        .from('contacts')
        .update(data)
        .eq('id', contact.id);
  }

  static Future<void> deleteContact(String contactId) async {
    await client.from('contacts').delete().eq('id', contactId);
  }

  static Future<List<Tag>> getTags() async {
    final response = await client.from('tags').select().order('name');
    return (response as List).map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Tag> createTag(String name, {String color = '#3b82f6'}) async {
    final ctx = await getAuthContext();
    final response = await client.from('tags').insert({
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'name': name.trim(),
      'color': color,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    return Tag.fromJson(response);
  }

  static Future<void> deleteTag(String tagId) async {
    await client.from('tags').delete().eq('id', tagId);
  }

  static Future<void> assignTagToContact(String contactId, String tagId) async {
    await client.from('contact_tags').upsert({
      'contact_id': contactId,
      'tag_id': tagId,
    });
  }

  static Future<void> removeTagFromContact(String contactId, String tagId) async {
    await client
        .from('contact_tags')
        .delete()
        .eq('contact_id', contactId)
        .eq('tag_id', tagId);
  }

  static Future<List<ContactNote>> getContactNotes(String contactId) async {
    final response = await client
        .from('contact_notes')
        .select()
        .eq('contact_id', contactId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => ContactNote.fromJson(e)).toList();
  }

  static Future<ContactNote> addContactNote(String contactId, String text) async {
    final ctx = await getAuthContext();
    final response = await client.from('contact_notes').insert({
      'contact_id': contactId,
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'note_text': text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    return ContactNote.fromJson(response);
  }

  static Future<void> deleteContactNote(String noteId) async {
    await client.from('contact_notes').delete().eq('id', noteId);
  }

  static Future<List<CustomField>> getCustomFields() async {
    final response = await client.from('custom_fields').select().order('created_at');
    return (response as List).map((e) => CustomField.fromJson(e)).toList();
  }

  static Future<CustomField> createCustomField(String name, String type) async {
    final ctx = await getAuthContext();
    final response = await client.from('custom_fields').insert({
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'field_name': name.trim(),
      'field_type': type,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    return CustomField.fromJson(response);
  }

  static Future<void> deleteCustomField(String id) async {
    await client.from('custom_fields').delete().eq('id', id);
  }

  // ============================================================
  // CONVERSATIONS & MESSAGES
  // ============================================================

  static Future<List<Conversation>> getConversations({
    ConversationStatus? status,
    String? assignedAgentId,
    String? searchQuery,
    int limit = 50,
  }) async {
    var query = client.from('conversations').select('''
      *,
      contacts (
        *,
        contact_tags (
          tags (*)
        )
      )
    ''');

    if (status != null) {
      query = query.eq('status', status.toDbValue());
    }

    if (assignedAgentId != null) {
      query = query.eq('assigned_agent_id', assignedAgentId);
    }

    final response = await query.order('last_message_at', ascending: false).limit(limit);
    return (response as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Conversation?> getOrCreateConversationForContact(String contactId) async {
    final existing = await client
        .from('conversations')
        .select('''
          *,
          contacts (
            *,
            contact_tags (
              tags (*)
            )
          )
        ''')
        .eq('contact_id', contactId)
        .maybeSingle();

    if (existing != null) {
      return Conversation.fromJson(existing);
    }

    final ctx = await getAuthContext();
    final insertData = {
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'contact_id': contactId,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final created = await client
        .from('conversations')
        .insert(insertData)
        .select('''
          *,
          contacts (
            *,
            contact_tags (
              tags (*)
            )
          )
        ''')
        .single();

    return Conversation.fromJson(created);
  }

  static Future<void> updateConversationStatus(String conversationId, ConversationStatus status) async {
    await client.from('conversations').update({
      'status': status.toDbValue(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  static Future<void> assignConversation(String conversationId, String? agentId) async {
    await client.from('conversations').update({
      'assigned_agent_id': agentId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  static Future<void> toggleAiAutoReply(String conversationId, bool disabled) async {
    await client.from('conversations').update({
      'ai_autoreply_disabled': disabled,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  static Future<List<Message>> getMessages(String conversationId) async {
    final response = await client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (response as List).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Stream<List<Map<String, dynamic>>> subscribeMessages(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  static Future<Message> insertMessage(Message message) async {
    final ctx = await getAuthContext();
    final data = message.toJson();
    data.remove('id'); // let postgres default gen_random_uuid
    if (!data.containsKey('sender_id') || (data['sender_id'] as String?)?.isEmpty == true) {
      data['sender_id'] = ctx['user_id'];
    }

    final response = await client
        .from('messages')
        .insert(data)
        .select()
        .single();

    // Bump conversation
    await client.from('conversations').update({
      'last_message_text': message.contentText ?? message.contentType.toDbValue(),
      'last_message_at': message.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', message.conversationId);

    return Message.fromJson(response);
  }

  static Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    await client
        .from('messages')
        .update({'status': status.toDbValue()})
        .eq('id', messageId);
  }

  // ============================================================
  // WHATSAPP CONFIG & TEMPLATES
  // ============================================================

  static Future<WhatsAppConfig?> getWhatsAppConfig() async {
    final response = await client.from('whatsapp_config').select().maybeSingle();
    if (response == null) return null;
    return WhatsAppConfig.fromJson(response);
  }

  static Future<void> saveWhatsAppConfig(WhatsAppConfig config) async {
    final ctx = await getAuthContext();
    final data = <String, dynamic>{
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'phone_number_id': config.phoneNumberId,
      if (config.wabaId != null && config.wabaId!.isNotEmpty) 'waba_id': config.wabaId,
      'access_token': config.accessToken,
      if (config.verifyToken != null && config.verifyToken!.isNotEmpty) 'verify_token': config.verifyToken,
      'status': config.status,
      'connected_at': (config.connectedAt ?? DateTime.now()).toIso8601String(),
      'mirror_inbound_media': config.mirrorInboundMedia,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final existing = await client
        .from('whatsapp_config')
        .select('id')
        .limit(1)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      await client
          .from('whatsapp_config')
          .update(data)
          .eq('id', existing['id']);
    } else {
      await client.from('whatsapp_config').insert(data);
    }
  }

  static Future<List<MessageTemplate>> getMessageTemplates() async {
    final response = await client
        .from('message_templates')
        .select()
        .order('name');
    return (response as List)
        .map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveMessageTemplate(MessageTemplate template) async {
    final ctx = await getAuthContext();
    final data = template.toJson();
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    data.remove('id');

    final existing = await client
        .from('message_templates')
        .select('id')
        .eq('account_id', ctx['account_id']!)
        .eq('name', template.name)
        .eq('language', template.language)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      await client.from('message_templates').update(data).eq('id', existing['id']);
    } else {
      await client.from('message_templates').insert(data);
    }
  }

  static Future<List<QuickReply>> getQuickReplies() async {
    final response = await client.from('quick_replies').select().order('title');
    return (response as List).map((e) => QuickReply.fromJson(e)).toList();
  }

  static Future<void> saveQuickReply(QuickReply qr) async {
    final ctx = await getAuthContext();
    final data = qr.toJson();
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    if (qr.id.isNotEmpty) {
      await client.from('quick_replies').update(data).eq('id', qr.id);
    } else {
      data.remove('id');
      await client.from('quick_replies').insert(data);
    }
  }

  static Future<void> deleteQuickReply(String id) async {
    await client.from('quick_replies').delete().eq('id', id);
  }

  // ============================================================
  // PIPELINES & DEALS
  // ============================================================

  static Future<List<Pipeline>> getPipelines() async {
    final response = await client.from('pipelines').select().order('created_at');
    final list = (response as List).map((e) => Pipeline.fromJson(e)).toList();
    if (list.isNotEmpty) return list;

    try {
      final defaultPipeline = await createPipeline('Sales Pipeline');
      final defaultStages = [
        {'name': 'Lead', 'color': '#3b82f6', 'position': 0},
        {'name': 'Contacted', 'color': '#f59e0b', 'position': 1},
        {'name': 'Proposal', 'color': '#8b5cf6', 'position': 2},
        {'name': 'Won', 'color': '#22c55e', 'position': 3},
        {'name': 'Lost', 'color': '#ef4444', 'position': 4},
      ];
      for (final s in defaultStages) {
        await createPipelineStage(
          pipelineId: defaultPipeline.id,
          name: s['name'] as String,
          position: s['position'] as int,
          color: s['color'] as String,
        );
      }
      return [defaultPipeline];
    } catch (e) {
      debugPrint('Auto-seed default pipeline note: $e');
      return list;
    }
  }

  static Future<Pipeline> createPipeline(String name) async {
    final ctx = await getAuthContext();
    final response = await client.from('pipelines').insert({
      'account_id': ctx['account_id'],
      'user_id': ctx['user_id'],
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    return Pipeline.fromJson(response);
  }

  static Future<List<PipelineStage>> getPipelineStages(String pipelineId) async {
    final response = await client
        .from('pipeline_stages')
        .select()
        .eq('pipeline_id', pipelineId)
        .order('position');
    return (response as List).map((e) => PipelineStage.fromJson(e)).toList();
  }

  static Future<PipelineStage> createPipelineStage({
    required String pipelineId,
    required String name,
    required int position,
    String color = '#3b82f6',
  }) async {
    final response = await client.from('pipeline_stages').insert({
      'pipeline_id': pipelineId,
      'name': name.trim(),
      'position': position,
      'color': color,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    return PipelineStage.fromJson(response);
  }

  static Future<void> deletePipelineStage(String stageId) async {
    await client.from('pipeline_stages').delete().eq('id', stageId);
  }

  static Future<List<Deal>> getDeals(String pipelineId) async {
    final response = await client
        .from('deals')
        .select('''
          *,
          contacts (*),
          pipeline_stages (*),
          profiles (*)
        ''')
        .eq('pipeline_id', pipelineId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Deal.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> updateDealStage(String dealId, String stageId) async {
    await client.from('deals').update({
      'stage_id': stageId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', dealId);
  }

  static Future<Deal> createDeal(Deal deal) async {
    final ctx = await getAuthContext();
    final data = deal.toJson();
    data.remove('id');
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    final response = await client.from('deals').insert(data).select().single();
    return Deal.fromJson(response);
  }

  static Future<void> updateDeal(Deal deal) async {
    final data = deal.toJson();
    data.remove('id');
    await client.from('deals').update(data).eq('id', deal.id);
  }

  static Future<void> deleteDeal(String dealId) async {
    await client.from('deals').delete().eq('id', dealId);
  }

  // ============================================================
  // BROADCASTS
  // ============================================================

  static Future<List<Broadcast>> getBroadcasts() async {
    final response = await client
        .from('broadcasts')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => Broadcast.fromJson(e)).toList();
  }

  static Future<Broadcast> createBroadcast(Broadcast broadcast) async {
    final ctx = await getAuthContext();
    final data = broadcast.toJson();
    data.remove('id');
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    final response = await client
        .from('broadcasts')
        .insert(data)
        .select()
        .single();
    return Broadcast.fromJson(response);
  }

  static Future<void> deleteBroadcast(String id) async {
    await client.from('broadcasts').delete().eq('id', id);
  }

  static Future<List<BroadcastRecipient>> getBroadcastRecipients(String broadcastId) async {
    final response = await client
        .from('broadcast_recipients')
        .select('''
          *,
          contacts (*)
        ''')
        .eq('broadcast_id', broadcastId)
        .order('created_at');
    return (response as List)
        .map((e) => BroadcastRecipient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // AUTOMATIONS & FLOWS
  // ============================================================

  static Future<List<Automation>> getAutomations() async {
    final response = await client.from('automations').select().order('created_at');
    return (response as List).map((e) => Automation.fromJson(e)).toList();
  }

  static Future<void> saveAutomation(Automation automation) async {
    final ctx = await getAuthContext();
    final data = automation.toJson();
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    if (automation.id.isNotEmpty) {
      await client.from('automations').update(data).eq('id', automation.id);
    } else {
      data.remove('id');
      await client.from('automations').insert(data);
    }
  }

  static Future<void> toggleAutomation(String id, bool isActive) async {
    await client.from('automations').update({'is_active': isActive}).eq('id', id);
  }

  static Future<void> deleteAutomation(String id) async {
    await client.from('automations').delete().eq('id', id);
  }

  static Future<List<FlowRow>> getFlows() async {
    final response = await client.from('flows').select().order('created_at');
    return (response as List).map((e) => FlowRow.fromJson(e)).toList();
  }

  static Future<void> saveFlow(FlowRow flow) async {
    final ctx = await getAuthContext();
    final data = flow.toJson();
    data['account_id'] = ctx['account_id'];
    data['user_id'] = ctx['user_id'];
    if (flow.id.isNotEmpty) {
      await client.from('flows').update(data).eq('id', flow.id);
    } else {
      data.remove('id');
      await client.from('flows').insert(data);
    }
  }

  static Future<void> deleteFlow(String id) async {
    await client.from('flows').delete().eq('id', id);
  }

  static Future<List<FlowNodeRow>> getFlowNodes(String flowId) async {
    final response = await client
        .from('flow_nodes')
        .select()
        .eq('flow_id', flowId)
        .order('created_at');
    return (response as List).map((e) => FlowNodeRow.fromJson(e)).toList();
  }

  static Future<void> saveFlowNode(FlowNodeRow node) async {
    final data = node.toJson();
    if (node.id.isNotEmpty) {
      await client.from('flow_nodes').update(data).eq('id', node.id);
    } else {
      data.remove('id');
      await client.from('flow_nodes').insert(data);
    }
  }

  static Future<void> deleteFlowNode(String id) async {
    await client.from('flow_nodes').delete().eq('id', id);
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  static Future<List<NotificationModel>> getNotifications() async {
    final user = currentUser;
    if (user == null) return [];
    final response = await client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(30);
    return (response as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  static Future<void> markNotificationAsRead(String id) async {
    await client.from('notifications').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ============================================================
  // SETTINGS & STORAGE
  // ============================================================

  static Future<AiConfig?> getAiConfig() async {
    final response = await client.from('ai_configs').select().maybeSingle();
    if (response == null) return null;
    return AiConfig.fromJson(response);
  }

  static Future<void> saveAiConfig(AiConfig config) async {
    final ctx = await getAuthContext();
    final accountId = config.accountId.isNotEmpty ? config.accountId : ctx['account_id']!;

    final data = <String, dynamic>{
      'account_id': accountId,
      'provider': config.provider,
      'model': config.model,
      'api_key': config.apiKeyEncrypted ?? '',
      'system_prompt': config.systemPrompt,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final existing = await client
        .from('ai_configs')
        .select('id')
        .limit(1)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      await client.from('ai_configs').update(data).eq('id', existing['id']);
    } else {
      await client.from('ai_configs').insert(data);
    }
  }

  static Future<List<AiKnowledgeDocument>> getKnowledgeDocuments() async {
    final response = await client
        .from('ai_knowledge_documents')
        .select()
        .order('created_at');
    return (response as List).map((e) => AiKnowledgeDocument.fromJson(e)).toList();
  }

  static Future<void> saveKnowledgeDocument(AiKnowledgeDocument doc) async {
    final ctx = await getAuthContext();
    final data = doc.toJson();
    data['account_id'] = ctx['account_id'];
    if (doc.id.isNotEmpty) {
      await client.from('ai_knowledge_documents').update(data).eq('id', doc.id);
    } else {
      data.remove('id');
      await client.from('ai_knowledge_documents').insert(data);
    }
  }

  static Future<void> deleteKnowledgeDocument(String id) async {
    await client.from('ai_knowledge_documents').delete().eq('id', id);
  }

  static Future<String> uploadChatMedia({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from('chat-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return client.storage.from('chat-media').getPublicUrl(path);
  }
}
