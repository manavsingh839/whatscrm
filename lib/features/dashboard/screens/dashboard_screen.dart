import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalConversations = 0;
  int _openConversations = 0;
  int _totalContacts = 0;
  double _pipelineValue = 0.0;
  bool _isLoading = true;
  List<int> _dailyVolumes = [0, 0, 0, 0, 0, 0, 0];
  List<String> _dayLabels = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final convs = await SupabaseService.getConversations();
      final contacts = await SupabaseService.getContacts();
      final pipelines = await SupabaseService.getPipelines();
      double pValue = 0.0;
      if (pipelines.isNotEmpty) {
        final deals = await SupabaseService.getDeals(pipelines.first.id);
        pValue = deals.fold(0.0, (sum, d) => sum + d.value);
      }

      // Generate last 7 days labels & compute counts
      final now = DateTime.now();
      final labels = <String>[];
      final counts = <int>[0, 0, 0, 0, 0, 0, 0];

      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        labels.add(DateFormat('E').format(d));
      }

      try {
        final sevenDaysAgo = DateTime(now.year, now.month, now.day - 6);
        final res = await SupabaseService.client
            .from('messages')
            .select('created_at')
            .gte('created_at', sevenDaysAgo.toIso8601String());

        for (final row in res) {
          final ca = DateTime.tryParse(row['created_at']?.toString() ?? '');
            if (ca != null) {
              final diff = now.difference(ca).inDays;
              if (diff >= 0 && diff < 7) {
                final idx = 6 - diff;
                if (idx >= 0 && idx < 7) counts[idx]++;
              }
            }
          }
        } catch (e) {
        debugPrint('Chart messages volume note: $e');
      }

      setState(() {
        _totalConversations = convs.length;
        _openConversations = convs.where((c) => c.status.name == 'open').length;
        _totalContacts = contacts.length;
        _pipelineValue = pValue;
        _dayLabels = labels;
        _dailyVolumes = counts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Overview of conversations, response times, and sales performance',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
          const SizedBox(height: 24),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 4 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: [
                  _buildMetricCard(
                    title: 'Total Conversations',
                    value: '$_totalConversations',
                    icon: LucideIcons.messageSquare,
                    color: AppColors.statusOpen,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Open Conversations',
                    value: '$_openConversations',
                    icon: LucideIcons.inbox,
                    color: AppColors.statusPending,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Total Contacts',
                    value: '$_totalContacts',
                    icon: LucideIcons.users,
                    color: AppColors.whatsappGreen,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Pipeline Value',
                    value: '\$${_pipelineValue.toStringAsFixed(0)}',
                    icon: LucideIcons.dollarSign,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Activity & Volume Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Message Volume & Response Trend',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Chip(
                      label: Text('Last 7 Days', style: TextStyle(fontSize: 11)),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (_dailyVolumes.fold(0, (a, b) => a > b ? a : b) + 5).toDouble().clamp(10.0, 1000.0),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => isDark ? AppColors.darkSurface : Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.round()} messages',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < _dayLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _dayLabels[idx],
                                      style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                if (value % 2 == 0) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10, color: AppColors.darkTextMuted),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(_dailyVolumes.length, (idx) {
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: _dailyVolumes[idx].toDouble(),
                                color: AppColors.primary,
                                width: 22,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
