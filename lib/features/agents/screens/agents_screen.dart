import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/account_models.dart';
import '../../../services/supabase_service.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AccountMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await SupabaseService.getAccountMembers();
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showInviteDialog() {
    AccountRole selectedRole = AccountRole.agent;
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite Team Member'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label / Teammate Name (optional)'),
                ),
                const SizedBox(height: 16),
                const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<AccountRole>(
                  initialValue: selectedRole,
                  items: [AccountRole.admin, AccountRole.agent, AccountRole.viewer].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
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
                try {
                  final token = await SupabaseService.createAccountInvitation(
                    role: selectedRole.name,
                    label: labelController.text.trim().isNotEmpty ? labelController.text.trim() : null,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invite generated! Token: $token (/join/$token)'),
                        action: SnackBarAction(
                          label: 'Copy Link',
                          onPressed: () => Clipboard.setData(ClipboardData(text: '/join/$token')),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Invite error: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to generate invite: $e')),
                    );
                  }
                }
              },
              child: const Text('Generate Invite Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agents & Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_members.length} team members',
                      style: const TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Invite Member'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: ListView.separated(
                      itemCount: _members.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = _members[index];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              _buildRoleBadge(member.role),
                            ],
                          ),
                          subtitle: Text(member.email ?? 'No email',
                              style: const TextStyle(color: AppColors.darkTextMuted, fontSize: 12)),
                          trailing: Text('Joined ${DateFormatter.formatRelative(member.joinedAt)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(AccountRole role) {
    Color color;
    switch (role) {
      case AccountRole.owner:
        color = const Color(0xFF8B5CF6); // Purple
        break;
      case AccountRole.admin:
        color = AppColors.primary;
        break;
      case AccountRole.agent:
        color = AppColors.statusOpen;
        break;
      case AccountRole.viewer:
        color = AppColors.darkTextMuted;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
