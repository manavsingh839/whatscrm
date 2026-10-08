import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/notification_models.dart';
import '../../../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final items = await SupabaseService.getNotifications();
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
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
          const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('In-app alerts for conversation assignments and mentions',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Center(
                        child: Text('No notifications right now.',
                            style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13)),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: ListView.separated(
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _notifications[index];

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.bell, size: 18, color: AppColors.primary),
                              ),
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(item.body ?? '', style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
                              trailing: Text(DateFormatter.formatRelative(item.createdAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
                              onTap: () async {
                                await SupabaseService.markNotificationAsRead(item.id);
                                _loadNotifications();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
