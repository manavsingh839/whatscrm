import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../services/supabase_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isCollapsed = false;

  final List<_NavItem> _navItems = const [
    _NavItem(title: 'Inbox', route: '/inbox', icon: LucideIcons.messageSquare),
    _NavItem(title: 'Contacts', route: '/contacts', icon: LucideIcons.users),
    _NavItem(title: 'Pipelines', route: '/pipelines', icon: LucideIcons.columns),
    _NavItem(title: 'Broadcasts', route: '/broadcasts', icon: LucideIcons.send),
    _NavItem(title: 'Automations', route: '/automations', icon: LucideIcons.zap),
    _NavItem(title: 'Flows', route: '/flows', icon: LucideIcons.gitFork),
    _NavItem(title: 'Dashboard', route: '/dashboard', icon: LucideIcons.layoutDashboard),
    _NavItem(title: 'Agents', route: '/agents', icon: LucideIcons.userCheck),
    _NavItem(title: 'Notifications', route: '/notifications', icon: LucideIcons.bell),
    _NavItem(title: 'Webhooks', route: '/webhooks', icon: LucideIcons.webhook),
    _NavItem(title: 'Settings', route: '/settings', icon: LucideIcons.settings),
  ];

  @override
  void initState() {
    super.initState();
    // Start presence heartbeat
    SupabaseService.touchPresence();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDesktop) {
      // Mobile / Tablet layout with bottom navigation or drawer
      return Scaffold(
        appBar: AppBar(
          title: Text(_getTitleForRoute(widget.currentRoute),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(LucideIcons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          child: _buildSidebarContent(isDrawer: true),
        ),
        body: widget.child,
      );
    }

    // Desktop Layout with persistent sidebar
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isCollapsed ? 72 : 240,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: _buildSidebarContent(isDrawer: false),
          ),
          Expanded(
            child: Column(
              children: [
                _buildDesktopHeader(isDark),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({required bool isDrawer}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // App Logo & Workspace Name
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.messageCircle, color: Colors.black, size: 20),
              ),
              if (!_isCollapsed || isDrawer) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'wacrm',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'WhatsApp CRM',
                        style: TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: _navItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = _navItems[index];
              final isSelected = widget.currentRoute.startsWith(item.route);

              return InkWell(
                onTap: () {
                  if (isDrawer) Navigator.of(context).pop();
                  context.go(item.route);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      if (!_isCollapsed || isDrawer) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? (isDark ? AppColors.darkText : AppColors.lightText)
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom User Profile & Sign Out
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: const Text('A', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
              if (!_isCollapsed || isDrawer) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Agent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('Online', style: TextStyle(fontSize: 10, color: AppColors.whatsappGreen)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.logOut, size: 16),
                  onPressed: () async {
                    await SupabaseService.signOut();
                    if (mounted) context.go('/login');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft, size: 18),
            onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
          ),
          const SizedBox(width: 12),
          Text(
            _getTitleForRoute(widget.currentRoute),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          // WhatsApp connection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.whatsappGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.whatsappGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: AppColors.whatsappGreen),
                SizedBox(width: 6),
                Text('Meta API Ready',
                    style: TextStyle(fontSize: 11, color: AppColors.whatsappGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitleForRoute(String route) {
    for (final item in _navItems) {
      if (route.startsWith(item.route)) return item.title;
    }
    return 'WhatsApp CRM';
  }
}

class _NavItem {
  final String title;
  final String route;
  final IconData icon;

  const _NavItem({required this.title, required this.route, required this.icon});
}
