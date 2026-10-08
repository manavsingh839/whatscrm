import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class JoinInviteScreen extends StatefulWidget {
  final String token;

  const JoinInviteScreen({super.key, required this.token});

  @override
  State<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends State<JoinInviteScreen> {
  bool _isLoading = true;
  bool _isRedeeming = false;
  Map<String, dynamic>? _inviteInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _peekInvite();
  }

  String get _tokenHash {
    final bytes = utf8.encode(widget.token.trim());
    return crypto.sha256.convert(bytes).toString();
  }

  Future<void> _peekInvite() async {
    try {
      final res = await SupabaseService.client.rpc(
        'peek_invitation',
        params: {'p_token_hash': _tokenHash},
      );
      setState(() {
        _inviteInfo = res as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid or expired invitation link.';
        _isLoading = false;
      });
    }
  }

  Future<void> _redeemInvite() async {
    setState(() => _isRedeeming = true);
    try {
      await SupabaseService.client.rpc(
        'redeem_invitation',
        params: {'p_token_hash': _tokenHash},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined organization!'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/inbox');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isRedeeming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.users, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 20),
                    const Text('Team Invitation',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_errorMessage != null) ...[
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.statusFailed, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Go to sign in'),
                      ),
                    ] else ...[
                      Text(
                        'You have been invited to join ${_inviteInfo?['account_name'] ?? 'the team'} as an ${_inviteInfo?['role'] ?? 'agent'}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.darkTextMuted),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _isRedeeming ? null : _redeemInvite,
                        child: _isRedeeming
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Accept and Join Team'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
