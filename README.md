# WhatsApp CRM (wacrm) — Flutter Rebuild

A complete, production-grade rebuild of the Node.js / Next.js WhatsApp Business CRM (`wacrm`) in **Flutter & Dart**.

## ✨ What is included (100% Feature Parity)

- 📥 **Shared Inbox**: Real-time WhatsApp messaging, interactive buttons/lists preview, voice note recording & player, templates picker, AI reply suggestions, conversation assignment & status toggles, internal notes, and linked deals.
- 👥 **Contacts Management**: Contact directory, tag segmentations, phone normalization, duplicate checks, and dynamic custom fields.
- 📊 **Sales Pipelines (Kanban)**: Interactive drag-and-drop deal board across configurable stages, revenue forecasting, and one-click jump to chat.
- 📢 **Broadcast Campaigns**: Mass outbound campaigns using Meta-approved templates, tag audience targeting, variable interpolation, and live delivery/read metrics.
- ⚡ **No-Code Automations**: Rule-based automation engine triggering on inbound messages, keywords, or tags with multi-step actions.
- 🔀 **Visual Flow Canvas**: Interactive canvas builder for conversational WhatsApp bots with buttons, list menus, and condition branches.
- 📈 **Real-Time Dashboard**: Response times, message volume trends, open ticket tracking, and cross-module activity stream.
- 🧑‍💼 **Team Accounts & RBAC**: Organization member management with Role-Based Access Control (`owner`, `admin`, `agent`, `viewer`) and link-based team invitations (`/join/:token`).
- 🤖 **AI Reply Assistant**: Bring-Your-Own-Key (BYOK) OpenAI / Anthropic integration with custom system prompts and knowledge base retrieval.
- ⚙️ **Meta Cloud API & Webhooks**: Permanent token management, 2FA registration, template sync from Meta, and a dedicated Dart Webhook Server.

---

## 🚀 Getting Started

### 1. Run the Flutter App
```bash
# Get dependencies
flutter pub get

# Run on Chrome Web
flutter run -d chrome

# Or run as Windows Desktop App
flutter run -d windows
```

### 2. Connect to your Supabase Project
In the app:
1. Navigate to **Settings → Supabase Server**.
2. Enter your `Supabase URL` and `Anon Key`.
3. Click **Save & Apply Endpoint**.

All 42 SQL migrations in `supabase/migrations` run directly on your Postgres database.

### 3. Run the WhatsApp Inbound Webhook Server (Optional for Inbound Messages)
```bash
# Set your environment variables
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-key"
$env:META_APP_SECRET="your-meta-app-secret"
$env:WHATSAPP_VERIFY_TOKEN="wacrm_verify_token"

# Launch the server
dart run server/webhook_server.dart
```

In Meta Developers WhatsApp Configuration:
- **Callback URL**: `https://your-domain.com/api/whatsapp/webhook`
- **Verify Token**: `wacrm_verify_token`
