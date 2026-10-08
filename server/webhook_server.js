/**
 * Standalone WhatsApp Cloud API Webhook Server for wacrm
 * 
 * Zero external dependencies — runs directly on Node.js (v18+)
 * Usage: node server/webhook_server.js
 * Default Port: 3000
 */

const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 3000;
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://okiocrxyxrzzyqhzsnmw.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'sb_publishable_BIZXS9a333ZZF8Id0gJ3ZA_y2UEV4Hf';
const DEFAULT_VERIFY_TOKEN = 'wacrm_verify_token_secure';
const ACCOUNT_ID = '8539e831-05bd-4118-9af0-d2a7a76d8c23';
const USER_ID = '1ab684fd-bb0c-4ec8-818d-3baf9ab6af53';

let authToken = null;

async function ensureAuth() {
  if (authToken) return authToken;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: 'wacrm.admin@gmail.com',
        password: 'password123456',
      }),
    });
    const data = await res.json();
    if (data.access_token) {
      authToken = data.access_token;
      console.log('✅ Webhook authenticated with Supabase session');
      return authToken;
    }
  } catch (e) {
    console.error('Auth error:', e.message);
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

// 3. Insert Inbound Message & Bump Conversation
async function processInboundMessage(message, contactProfile) {
  const fromPhone = message.from;
  const contactName = contactProfile?.name || fromPhone;
  console.log(`\n📩 [INBOUND] Message from ${contactName} (${fromPhone}): "${message.text?.body || message.type}"`);

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

  console.log(`✨ [SUCCESS] Message synced to Inbox for ${contactName}! Conversation ID: ${conv.id}`);
}

// 4. Update Outbound Message Delivery Status
async function processStatusUpdate(status) {
  const wamid = status.id;
  const newStatus = status.status; // 'sent', 'delivered', 'read', 'failed'
  console.log(`📊 [STATUS] Message ${wamid} -> ${newStatus}`);

  await supabaseRequest(`messages?message_id=eq.${encodeURIComponent(wamid)}`, {
    method: 'PATCH',
    body: JSON.stringify({
      status: newStatus,
    }),
  });
}

// Create HTTP Server
const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check endpoint
  if (pathname === '/' || pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'wacrm-whatsapp-webhook', port: PORT }));
    return;
  }

  // Meta Webhook endpoint
  if (pathname === '/api/whatsapp/webhook' || pathname === '/webhook') {
    // GET: Verification Challenge from Meta
    if (req.method === 'GET') {
      const mode = parsedUrl.query['hub.mode'];
      const token = parsedUrl.query['hub.verify_token'];
      const challenge = parsedUrl.query['hub.challenge'];

      console.log(`[VERIFY REQUEST] mode=${mode}, token=${token}`);

      if (mode === 'subscribe' && (token === DEFAULT_VERIFY_TOKEN || !token)) {
        console.log('✅ [VERIFIED] Meta Webhook challenge verified successfully!');
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(challenge);
      } else {
        console.warn(`⚠️ [VERIFY FAILED] Token mismatch: received "${token}", expected "${DEFAULT_VERIFY_TOKEN}"`);
        res.writeHead(403, { 'Content-Type': 'text/plain' });
        res.end('Verification token mismatch');
      }
      return;
    }

    // POST: Inbound Message / Status Event from Meta
    if (req.method === 'POST') {
      let bodyData = '';
      req.on('data', chunk => {
        bodyData += chunk;
      });

      req.on('end', async () => {
        // Immediate 200 OK acknowledgment to Meta
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'received' }));

        try {
          const payload = JSON.parse(bodyData);
          const entries = payload.entry || [];

          for (const entry of entries) {
            const changes = entry.changes || [];
            for (const change of changes) {
              const value = change.value || {};

              // Handle delivery status receipts
              if (Array.isArray(value.statuses)) {
                for (const st of value.statuses) {
                  await processStatusUpdate(st);
                }
              }

              // Handle inbound customer messages
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
          console.error('[ERROR] Failed to process webhook body:', err.message);
        }
      });
      return;
    }
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(PORT, async () => {
  await ensureAuth();
  console.log(`====================================================`);
  console.log(`🚀 wacrm WhatsApp Webhook Server is LIVE!`);
  console.log(`📡 Listening on: http://localhost:${PORT}`);
  console.log(`🔗 Webhook URL: http://localhost:${PORT}/api/whatsapp/webhook`);
  console.log(`🔑 Verify Token: ${DEFAULT_VERIFY_TOKEN}`);
  console.log(`====================================================`);
});
