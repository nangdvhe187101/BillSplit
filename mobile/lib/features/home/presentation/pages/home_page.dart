import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/statistics_repository.dart';
import '../widgets/edit_profile_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');
  late final StatisticsRepository _statisticsRepository;

  DashboardStatsModel? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _statisticsRepository = StatisticsRepository(dioClient: context.read<DioClient>());
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _statisticsRepository.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể kết nối đến máy chủ thống kê';
        _isLoading = false;
      });
    }
  }

  void _showEditProfileDialog() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => EditProfileDialog(currentUser: authState.user),
    );

    if (updated == true && mounted) {
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    final netBalance = _stats?.netBalance ?? 0.0;
    final totalReceivable = _stats?.totalReceivable ?? 0.0;
    final totalPayable = _stats?.totalPayable ?? 0.0;
    final isNetPositive = netBalance >= 0;

    final isGuest = user == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            if (isGuest) {
              context.push('/login');
            } else {
              _showEditProfileDialog();
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                child: user?.avatarUrl == null
                    ? Icon(isGuest ? Icons.person_outline_rounded : Icons.person, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isGuest ? 'Khách trải nghiệm' : (user?.fullName ?? 'Người dùng'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isGuest ? Icons.login_rounded : Icons.edit_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  Text(
                    isGuest
                        ? 'Chạm để đăng nhập / đăng ký'
                        : (user != null && user.bankBin.isNotEmpty
                            ? 'BIN: ${user.bankBin} • ${user.bankAccountNo}'
                            : 'Bấm để sửa tài khoản VietQR'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Đăng nhập',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Làm mới số liệu',
              onPressed: _loadStats,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              tooltip: 'Đăng xuất',
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thẻ Tổng Quan Tài Chính (KPI Overview Card)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Số dư ròng tổng thể',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLoading
                            ? '...'
                            : '${isNetPositive ? '+' : ''}${_currencyFormat.format(netBalance)} đ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          // Cần thu về
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Cần thu về',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLoading ? '...' : '${_currencyFormat.format(totalReceivable)} đ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Cần trả
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Cần trả',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLoading ? '...' : '${_currencyFormat.format(totalPayable)} đ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Tiện Ích Thao Tác Nhanh (Quick Actions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickAction(
                      icon: Icons.qr_code_rounded,
                      label: 'QR nhận tiền',
                      onTap: () {
                        final authState = context.read<AuthBloc>().state;
                        final user = authState is Authenticated ? authState.user : null;
                        context.push(
                          '/qr-payment',
                          extra: {
                            'debtId': null,
                            'debtorName': '',
                            'amount': 0.0,
                            'debtCode': '',
                            'title': 'Mã QR nhận tiền của ${user?.fullName ?? "bạn"}',
                          },
                        );
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Tạo bill mới',
                      onTap: () => context.push('/split'),
                    ),
                    _buildQuickAction(
                      icon: Icons.group_outlined,
                      label: 'Tạo nhóm',
                      onTap: () => context.push('/groups'),
                    ),
                    _buildQuickAction(
                      icon: Icons.people_alt_outlined,
                      label: 'Bạn bè',
                      onTap: () => context.push('/friends'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 3. Biểu đồ chi tiêu theo danh mục (PieChart fl_chart)
                _buildCategoryChartSection(),
                const SizedBox(height: 28),

                // 4. Biểu đồ xu hướng tài chính theo tháng (BarChart fl_chart)
                _buildMonthlyTrendSection(),
                const SizedBox(height: 28),

                // 5. Giao dịch gần đây (Recent Transactions)
                _buildRecentTransactionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChartSection() {
    final categories = _stats?.categoryBreakdown ?? [];
    final hasData = categories.isNotEmpty && categories.any((c) => c.amount > 0);

    final colors = [
      AppColors.primary,
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân loại chi tiêu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tỷ trọng các nhóm chi tiêu trong nhóm',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (!hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có chi tiêu nào được ghi nhận', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: categories.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final cat = entry.value;
                        final color = colors[idx % colors.length];
                        return PieChartSectionData(
                          color: color,
                          value: cat.amount,
                          title: '${cat.percentage.toStringAsFixed(0)}%',
                          radius: 28,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cat = entry.value;
                      final color = colors[idx % colors.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.category,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${_currencyFormat.format(cat.amount)} đ',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendSection() {
    final trends = _stats?.monthlyTrends ?? [];
    final hasData = trends.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Xu hướng chi tiêu & Thu hồi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Chi', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Thu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (!hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có số liệu theo tháng', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calculateMaxBarY(trends),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < trends.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                trends[idx].month,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: trends.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: t.spent > 0 ? t.spent : 1000,
                          color: AppColors.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: t.collected > 0 ? t.collected : 1000,
                          color: const Color(0xFF10B981),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateMaxBarY(List<MonthlyTrendModel> trends) {
    double maxVal = 100000;
    for (final t in trends) {
      if (t.spent > maxVal) maxVal = t.spent;
      if (t.collected > maxVal) maxVal = t.collected;
    }
    return maxVal * 1.25;
  }

  Widget _buildRecentTransactionsSection() {
    final transactions = _stats?.recentTransactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giao dịch công nợ gần đây',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'Chưa có giao dịch công nợ nào phát sinh.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...transactions.map((tx) {
            final isPaid = tx.status == 'Paid';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.success.withValues(alpha: 0.15) : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
                      color: isPaid ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.expenseTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${tx.debtorName} • Mã: ${tx.debtCode}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_currencyFormat.format(tx.amount)} đ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isPaid ? AppColors.success : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPaid ? 'Đã gạch nợ' : 'Đang chờ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.success : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primarySoft.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
