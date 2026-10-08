/**
 * Vercel Serverless Function for WhatsApp Cloud API Webhook
 * Endpoint: /api/whatsapp/webhook
 * 
 * Handles:
 * 1. GET: Meta Webhook hub.challenge verification
 * 2. POST: Inbound customer messages & delivery status receipts (sent, delivered, read)
 * 3. Syncs directly to Supabase Database (contacts, conversations, messages)
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://okiocrxyxrzzyqhzsnmw.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'sb_publishable_BIZXS9a333ZZF8Id0gJ3ZA_y2UEV4Hf';
const DEFAULT_VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN || 'wacrm_verify_token_secure';
const ACCOUNT_ID = process.env.ACCOUNT_ID || '8539e831-05bd-4118-9af0-d2a7a76d8c23';
const USER_ID = process.env.USER_ID || '1ab684fd-bb0c-4ec8-818d-3baf9ab6af53';

let cachedAuthToken = null;

async function ensureAuth() {
  if (cachedAuthToken) return cachedAuthToken;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: process.env.SUPABASE_ADMIN_EMAIL || 'wacrm.admin@gmail.com',
        password: process.env.SUPABASE_ADMIN_PASSWORD || 'password123456',
      }),
    });
    const data = await res.json();
    if (data.access_token) {
      cachedAuthToken = data.access_token;
      return cachedAuthToken;
    }
  } catch (e) {
    console.error('Supabase Auth Error:', e.message);
  }
  return SUPABASE_ANON_KEY;
}

async function supabaseRequest(endpoint, options = {}) {
  const token = await ensureAuth();
  const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
    ...(options.headers || {}),
  };

  const response = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    ...options,
    headers,
  });

  const text = await response.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

// 1. Find or create Contact
async function getOrCreateContact(phone, name) {
  const cleanPhone = phone.startsWith('+') ? phone : `+${phone}`;
  const existing = await supabaseRequest(`contacts?phone=eq.${encodeURIComponent(cleanPhone)}&select=*`);
  if (Array.isArray(existing) && existing.length > 0) {
    return existing[0];
  }

  const inserted = await supabaseRequest('contacts', {
    method: 'POST',
    body: JSON.stringify({
      account_id: ACCOUNT_ID,
      user_id: USER_ID,
      phone: cleanPhone,
      name: name || cleanPhone,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }),
  });

  return Array.isArray(inserted) && inserted.length > 0 ? inserted[0] : null;
}

// 2. Find or create Conversation
async function getOrCreateConversation(contactId) {
  const existing = await supabaseRequest(`conversations?contact_id=eq.${contactId}&select=*`);
  if (Array.isArray(existing) && existing.length > 0) {
    return existing[0];
  }

  const inserted = await supabaseRequest('conversations', {
    method: 'POST',
    body: JSON.stringify({
      account_id: ACCOUNT_ID,
      user_id: USER_ID,
      contact_id: contactId,
      status: 'open',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }),
  });

  return Array.isArray(inserted) && inserted.length > 0 ? inserted[0] : null;
}

// 3. Process Inbound Message
async function processInboundMessage(message, contactProfile) {
  const fromPhone = message.from;
  const contactName = contactProfile?.name || fromPhone;
  console.log(`[INBOUND] Message from ${contactName} (${fromPhone}): "${message.text?.body || message.type}"`);

  const contact = await getOrCreateContact(fromPhone, contactName);
  if (!contact) {
    console.error('[ERROR] Could not resolve contact for:', fromPhone);
    return;
  }

  const conv = await getOrCreateConversation(contact.id);
  if (!conv) {
    console.error('[ERROR] Could not resolve conversation for contact:', contact.id);
    return;
  }

  let textContent = message.text?.body || null;
  let mediaUrl = null;
  let contentType = message.type || 'text';

  if (contentType === 'image' && message.image) {
    textContent = message.image.caption || null;
  } else if (contentType === 'document' && message.document) {
    textContent = message.document.filename || message.document.caption || null;
  } else if (contentType === 'interactive' && message.interactive) {
    textContent = message.interactive.button_reply?.title || message.interactive.list_reply?.title || 'Interactive Reply';
  } else if (contentType === 'button' && message.button) {
    textContent = message.button.text || 'Button Click';
  }

  // Insert message into Supabase
  await supabaseRequest('messages', {
    method: 'POST',
    body: JSON.stringify({
      conversation_id: conv.id,
      sender_type: 'customer',
      content_type: contentType,
      content_text: textContent,
      media_url: mediaUrl,
      message_id: message.id,
      status: 'delivered',
      created_at: new Date().toISOString(),
    }),
  });

  // Update conversation last message
  await supabaseRequest(`conversations?id=eq.${conv.id}`, {
    method: 'PATCH',
    body: JSON.stringify({
      last_message_text: textContent || contentType,
      last_message_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }),
  });

  console.log(`[SUCCESS] Synced inbound message to Supabase! Conversation: ${conv.id}`);
}

// 4. Process Status Update (Delivery / Read ticks)
async function processStatusUpdate(status) {
  const wamid = status.id;
  const newStatus = status.status;
  console.log(`[STATUS] Message ${wamid} -> ${newStatus}`);

  await supabaseRequest(`messages?message_id=eq.${encodeURIComponent(wamid)}`, {
    method: 'PATCH',
    body: JSON.stringify({
      status: newStatus,
    }),
  });
}

module.exports = async function handler(req, res) {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // 1. GET: Meta Webhook Verification Challenge
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    console.log(`[VERIFY REQUEST] mode=${mode}, token=${token}`);

    if (mode === 'subscribe' && (token === DEFAULT_VERIFY_TOKEN || !token)) {
      console.log('✅ Meta Webhook challenge verified!');
      return res.status(200).send(challenge);
    }
    return res.status(403).send('Verification token mismatch');
  }

  // 2. POST: Inbound Message / Status Event from Meta
  if (req.method === 'POST') {
    // Vercel parses JSON bodies automatically into req.body
    let payload = req.body;
    if (typeof payload === 'string') {
      try {
        payload = JSON.parse(payload);
      } catch {
        payload = {};
      }
    }

    // Acknowledge Meta immediately with 200 OK
    try {
      const entries = payload?.entry || [];
      for (const entry of entries) {
        const changes = entry.changes || [];
        for (const change of changes) {
          const value = change.value || {};

          // Delivery status receipts
          if (Array.isArray(value.statuses)) {
            for (const st of value.statuses) {
              await processStatusUpdate(st);
            }
          }

          // Inbound customer messages
          if (Array.isArray(value.messages)) {
            const contacts = value.contacts || [];
            for (let i = 0; i < value.messages.length; i++) {
              const msg = value.messages[i];
              const profile = contacts[i]?.profile || contacts[0]?.profile;
              await processInboundMessage(msg, profile);
            }
          }
        }
      }
    } catch (err) {
      console.error('[ERROR] Processing webhook body:', err.message);
    }

    return res.status(200).json({ status: 'received' });
  }

  return res.status(405).send('Method Not Allowed');
};
