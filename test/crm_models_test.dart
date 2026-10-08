import 'package:flutter_test/flutter_test.dart';
import 'package:whtsappcrm/models/account_models.dart';
import 'package:whtsappcrm/models/broadcast_models.dart';
import 'package:whtsappcrm/models/contact_models.dart';
import 'package:whtsappcrm/models/conversation_models.dart';
import 'package:whtsappcrm/models/flow_models.dart';
import 'package:whtsappcrm/models/pipeline_models.dart';
import 'package:whtsappcrm/models/whatsapp_models.dart';

void main() {
  group('CRM Models & Parity Tests', () {
    test('Contact & Tag null-safe UUID JSON output', () {
      final tag = Tag(
        id: '',
        userId: '',
        name: 'VIP Client',
        color: '#25D366',
        createdAt: DateTime.now(),
      );
      final jsonTag = tag.toJson();
      expect(jsonTag.containsKey('id'), false);
      expect(jsonTag.containsKey('account_id'), false);
      expect(jsonTag['name'], 'VIP Client');

      final contact = Contact(
        id: '',
        userId: '',
        accountId: '',
        phone: '+14155552671',
        name: 'John Doe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final jsonContact = contact.toJson();
      expect(jsonContact.containsKey('id'), false);
      expect(jsonContact.containsKey('account_id'), false);
      expect(jsonContact['phone'], '+14155552671');
      expect(jsonContact['name'], 'John Doe');
    });

    test('Conversation & Message serialization', () {
      final msg = Message(
        id: '',
        conversationId: 'c123',
        senderType: SenderType.agent,
        contentType: MessageContentType.text,
        contentText: 'Hello from Flutter!',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );
      expect(msg.isOutbound, true);

      final jsonMsg = msg.toJson();
      expect(jsonMsg.containsKey('id'), false);
      expect(jsonMsg['conversation_id'], 'c123');
      expect(jsonMsg['content_text'], 'Hello from Flutter!');
      expect(jsonMsg['sender_type'], 'agent');
    });

    test('Pipeline, Stage and Deal calculation', () {
      final deal1 = Deal(
        id: 'd1',
        userId: 'u1',
        pipelineId: 'p1',
        stageId: 's1',
        title: 'Enterprise Subscription',
        value: 5000.0,
        status: DealStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final deal2 = Deal(
        id: 'd2',
        userId: 'u1',
        pipelineId: 'p1',
        stageId: 's2',
        title: 'Setup Fee',
        value: 1200.0,
        status: DealStatus.won,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final total = deal1.value + deal2.value;
      expect(total, 6200.0);
      expect(deal2.status, DealStatus.won);
    });

    test('Broadcast & Recipient models', () {
      final bcast = Broadcast(
        id: 'b1',
        userId: 'u1',
        name: 'Launch Notification',
        templateName: 'app_launch_v1',
        templateLanguage: 'en',
        status: BroadcastStatus.draft,
        createdAt: DateTime.now(),
      );

      expect(bcast.status, BroadcastStatus.draft);
      expect(bcast.name, 'Launch Notification');
      expect(bcast.templateLanguage, 'en');
    });

    test('QuickReply serialization', () {
      final qr = QuickReply(
        id: '',
        accountId: '',
        userId: '',
        title: '/pricing',
        kind: 'text',
        contentText: 'Check our pricing at wacrm.app/pricing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(qr.title, '/pricing');
      expect(qr.contentText, 'Check our pricing at wacrm.app/pricing');
      final json = qr.toJson();
      expect(json.containsKey('id'), false);
      expect(json['title'], '/pricing');
      expect(json['content_text'], 'Check our pricing at wacrm.app/pricing');
    });

    test('Flow & FlowNode models', () {
      final flow = FlowRow(
        id: 'f1',
        accountId: 'a1',
        userId: 'u1',
        name: 'Customer Support Flow',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(flow.isActive, true);

      final node = FlowNodeRow(
        id: 'n1',
        flowId: flow.id,
        nodeKey: 'welcome_message',
        nodeType: 'message',
        positionX: 120.0,
        positionY: 80.0,
        config: {'text': 'Welcome to our store!'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(node.nodeKey, 'welcome_message');
      expect(node.config['text'], 'Welcome to our store!');
    });

    test('AccountMember & AccountRole enum', () {
      expect(AccountRole.fromString('admin'), AccountRole.admin);
      expect(AccountRole.fromString('agent'), AccountRole.agent);
      expect(AccountRole.fromString('viewer'), AccountRole.viewer);
      expect(AccountRole.fromString('owner'), AccountRole.owner);
    });
  });
}
