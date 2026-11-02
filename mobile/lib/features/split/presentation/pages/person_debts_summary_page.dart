import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/vietqr_encoder.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/debt_detail_model.dart';
import '../../data/models/person_debt_summary_model.dart';
import '../../data/repositories/debt_repository.dart';

/// Màn hình chức năng riêng: SỔ NỢ GỘP THEO TỪNG NGƯỜI (Aggregated Debts by Person)
/// Tự động cộng dồn các bill của cùng một người (VD: bill A 50k + bill B 20k = 70k)
/// đồng thời hiển thị chi tiết lịch sử từng bill, hỗ trợ tạo VietQR gộp và gạch nợ.
class PersonDebtsSummaryPage extends StatefulWidget {
  const PersonDebtsSummaryPage({super.key});

  @override
  State<PersonDebtsSummaryPage> createState() => _PersonDebtsSummaryPageState();
}

class _PersonDebtsSummaryPageState extends State<PersonDebtsSummaryPage> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final TextEditingController _searchController = TextEditingController();

  late final DebtRepository _debtRepository;
  List<PersonDebtSummaryModel> _allPersons = [];
  List<PersonDebtSummaryModel> _filteredPersons = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'pending', 'settled'

  // Quản lý trạng thái mở rộng (expand) của từng person card
  final Set<String> _expandedPersonKeys = {};

  @override
  void initState() {
    super.initState();
    _debtRepository = DebtRepository(dioClient: context.read<DioClient>());
    _loadAggregatedDebts();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAggregatedDebts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _debtRepository.getDebtsGroupedByPerson(asCreditor: true);
      if (!mounted) return;
      setState(() {
        _allPersons = list;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải dữ liệu sổ nợ gộp. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredPersons = _allPersons.where((p) {
        // Lọc theo từ khóa tìm kiếm
        final matchName = p.debtorName.toLowerCase().contains(query);
        final matchPhone = (p.phoneNumber ?? '').toLowerCase().contains(query);
        final matchSearch = query.isEmpty || matchName || matchPhone;

        // Lọc theo tab trạng thái
        if (!matchSearch) return false;
        if (_selectedFilter == 'pending') {
          return p.hasPendingDebts;
        } else if (_selectedFilter == 'settled') {
          return p.isFullySettled;
        }
        return true;
      }).toList();
    });
  }

  double get _totalPendingAll {
    return _allPersons.fold(0.0, (sum, p) => sum + p.totalPendingAmount);
  }

  int get _totalPendingDebtorsCount {
    return _allPersons.where((p) => p.hasPendingDebts).length;
  }

  String _getPersonKey(PersonDebtSummaryModel person) {
    return person.debtorId ?? 'custom_${person.debtorName}';
  }

  void _toggleExpand(String key) {
    setState(() {
      if (_expandedPersonKeys.contains(key)) {
        _expandedPersonKeys.remove(key);
      } else {
        _expandedPersonKeys.add(key);
      }
    });
  }

  // --- THAO TÁC 1: XÁC NHẬN GẠCH NỢ TỪNG BILL LẺ ---
  Future<void> _onSettleSingleDebt(DebtDetailModel debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận đã nhận tiền?'),
        content: Text(
          'Đánh dấu khoản nợ "${debt.expenseTitle}" (${_currencyFormat.format(debt.amount)} đ) của "${debt.debtorName}" là đã thanh toán?',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận gạch nợ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await _debtRepository.manualSettle(debt.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    if (result.success) {
      _loadAggregatedDebts();
    }
  }

  // --- THAO TÁC 2: XÁC NHẬN GẠCH NỢ TOÀN BỘ BILL CỘNG DỒN CỦA 1 NGƯỜI ---
  Future<void> _onSettleAllDebtsForPerson(PersonDebtSummaryModel person) async {
    final pendingDebts = person.pendingDebts;
    if (pendingDebts.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gạch nợ toàn bộ (Cộng dồn)?'),
        content: Text(
          'Xác nhận "${person.debtorName}" đã thanh toán gộp toàn bộ ${pendingDebts.length} bill với tổng số tiền ${_currencyFormat.format(person.totalPendingAmount)} đ?',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Xác nhận đã trả hết'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ids = pendingDebts.map((d) => d.id).toList();
    final result = await _debtRepository.settleMultipleDebts(ids);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    if (result.success) {
      _loadAggregatedDebts();
    }
  }

  // --- THAO TÁC 3: HIỂN THỊ MÃ VIETQR GỘP TỔNG NỢ CỦA NGƯỜI ĐÓ ---
  void _showAggregatedQrDialog(PersonDebtSummaryModel person) {
    final authState = context.read<AuthBloc>().state;
    String bankBin = '970422'; // Mặc định MBBank
    String bankAccountNo = '0912345678';
    String bankAccountName = 'NGUYEN VAN A';

    if (authState is Authenticated) {
      bankBin = authState.user.bankBin;
      bankAccountNo = authState.user.bankAccountNo;
      bankAccountName = authState.user.bankAccountName;
    }

    final pendingDebts = person.pendingDebts;
    final codes = pendingDebts.map((d) => d.debtCode).take(3).join(' ');
    final memo = '$codes TRANO';

    final qrPayload = VietQrEncoder.encode(
      bankBin: bankBin,
      accountNo: bankAccountNo,
      amount: person.totalPendingAmount,
      memo: memo,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                'Mã VietQR gộp: ${person.debtorName}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Gộp ${pendingDebts.length} khoản nợ • Tổng cộng dồn: ${_currencyFormat.format(person.totalPendingAmount)} đ',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryLight, width: 1.5),
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryDark),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildCopyTile('STK nhận:', bankAccountNo),
                    const SizedBox(height: 6),
                    _buildCopyTile('Chủ tài khoản:', bankAccountName),
                    const SizedBox(height: 6),
                    _buildCopyTile('Nội dung:', memo),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Đóng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- THAO TÁC 4: NHẮC NỢ GỘP VÀ CHIA SẺ NỘI DUNG TỔNG HỢP ---
  void _onShareReminder(PersonDebtSummaryModel person) {
    final authState = context.read<AuthBloc>().state;
    String bankAccountNo = '';
    String bankAccountName = '';

    if (authState is Authenticated) {
      bankAccountNo = authState.user.bankAccountNo;
      bankAccountName = authState.user.bankAccountName;
    }

    final buffer = StringBuffer();
    buffer.writeln('Chào ${person.debtorName}, bạn hiện có ${person.pendingDebts.length} khoản nợ cần thanh toán:');

    for (int i = 0; i < person.pendingDebts.length; i++) {
      final d = person.pendingDebts[i];
      buffer.writeln('${i + 1}. ${d.expenseTitle}: ${_currencyFormat.format(d.amount)} đ (Mã: ${d.debtCode})');
    }

    buffer.writeln('👉 TỔNG NỢ CỘNG DỒN: ${_currencyFormat.format(person.totalPendingAmount)} đ');
    if (bankAccountNo.isNotEmpty) {
      buffer.writeln('Thông tin nhận: STK $bankAccountNo ($bankAccountName)');
    }
    buffer.writeln('Nhờ bạn chuyển khoản giúp mình nhé! Cảm ơn bạn.');

    final message = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nội dung nhắc nợ gộp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(message, style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép nội dung nhắc nợ vào bộ nhớ tạm'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Sao chép'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(message, subject: 'Nhắc nợ: ${person.debtorName}');
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Chia sẻ'),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyTile(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: val));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã chép: $val'), duration: const Duration(seconds: 1)),
            );
          },
          child: Row(
            children: [
              Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sổ nợ gộp theo người'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadAggregatedDebts,
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: AppColors.primary),
            tooltip: 'Về trang chủ',
            onPressed: () => context.go('/home', extra: {'refresh': true}),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAggregatedDebts,
          color: AppColors.primary,
          child: Column(
            children: [
              // 1. HEADER HERO: Tổng nợ cộng dồn toàn bộ
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TỔNG TIỀN CẦN THU (CỘNG DỒN)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLoading ? '...' : '${_currencyFormat.format(_totalPendingAll)} đ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalPendingDebtorsCount người hiện đang có khoản nợ chưa trả',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // 2. TÌM KIẾM & BỘ LỌC
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm người nợ theo tên hoặc SĐT...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilter();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildFilterChip('Tất cả', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Còn nợ', 'pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Đã trả xong', 'settled'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. DANH SÁCH NGƯỜI NỢ VỚI CÔNG NỢ CỘNG DỒN
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _filteredPersons.isEmpty
                            ? _buildEmptyView()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: _filteredPersons.length,
                                itemBuilder: (context, index) {
                                  final person = _filteredPersons[index];
                                  return _buildPersonCard(person);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filterKey;
          });
          _applyFilter();
        }
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadAggregatedDebts, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'Chưa tìm thấy người nợ nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Các khoản nợ tạo ra từ việc chia bill sẽ tự động được gom nhóm và cộng dồn theo từng người tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD ĐẠI DIỆN CHO 1 NGƯỜI (CỘNG DỒN + LỊCH SỬ NỢ) ---
  Widget _buildPersonCard(PersonDebtSummaryModel person) {
    final key = _getPersonKey(person);
    final isExpanded = _expandedPersonKeys.contains(key);
    final hasPending = person.hasPendingDebts;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPending ? AppColors.primaryLight : AppColors.border,
          width: hasPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasPending
                ? AppColors.primarySoft.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. HEADER CARD: Thông tin người nợ & TỔNG TIỀN CỘNG DỒN
          InkWell(
            onTap: () => _toggleExpand(key),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: hasPending ? AppColors.primarySoft : const Color(0xFFF1F5F9),
                    child: Text(
                      person.debtorName.isNotEmpty ? person.debtorName.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: hasPending ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                person.debtorName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: person.isAppUser
                                    ? AppColors.primarySoft
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                person.isAppUser ? 'Thành viên' : 'Khách ngoài',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: person.isAppUser ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasPending
                              ? 'Đang nợ ${person.pendingCount} khoản bill'
                              : 'Đã thanh toán sòng phẳng (${person.paidCount} bill)',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasPending ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // TỔNG TIỀN CỘNG DỒN
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasPending
                            ? '${_currencyFormat.format(person.totalPendingAmount)} đ'
                            : '0 đ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: hasPending ? AppColors.error : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            isExpanded ? 'Thu gọn' : 'Xem ${person.debts.length} bill',
                            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. THANH CÔNG CỤ NHANH KHI ĐANG CÒN NỢ
          if (hasPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.35),
                border: const Border(
                  top: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  // Nút 1: Tạo VietQR gộp
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAggregatedQrDialog(person),
                      icon: const Icon(Icons.qr_code_rounded, size: 16, color: AppColors.primary),
                      label: const Text('QR gộp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút 2: Nhắc nợ gộp
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _onShareReminder(person),
                      icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.primaryDark),
                      label: const Text('Nhắc nợ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút 3: Gạch nợ toàn bộ
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _onSettleAllDebtsForPerson(person),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text('Đã trả hết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. CHI TIẾT LỊCH SỬ NỢ CỦA NGƯỜI NÀY (Expandable History)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lịch sử chi tiết các bill:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${person.debts.length} giao dịch',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...person.debts.map((debt) => _buildDebtItemRow(debt)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- MỖI BILL LẺ TRONG LỊCH SỬ CỦA 1 NGƯỜI ---
  Widget _buildDebtItemRow(DebtDetailModel debt) {
    final isPaid = debt.status.toLowerCase() == 'paid';
    final dateStr = debt.createdAt != null ? _dateFormat.format(debt.createdAt!.toLocal()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFF8FAFC) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPaid ? AppColors.border : AppColors.primaryLight),
      ),
      child: Row(
        children: [
          // Icon trạng thái bill
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isPaid ? AppColors.success.withValues(alpha: 0.12) : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
              size: 18,
              color: isPaid ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          // Tiêu đề & thời gian & mã bill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.expenseTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                    color: isPaid ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mã: ${debt.debtCode} ${dateStr.isNotEmpty ? "• $dateStr" : ""}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Số tiền & nút thao tác
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_currencyFormat.format(debt.amount)} đ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPaid ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              if (!isPaid)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Xem QR lẻ của bill này
                    InkWell(
                      onTap: () {
                        context.push(
                          '/qr-payment',
                          extra: {
                            'debtId': debt.id,
                            'debtorName': debt.debtorName,
                            'amount': debt.amount,
                            'debtCode': debt.debtCode,
                            'title': debt.expenseTitle,
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('QR lẻ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Gạch nợ bill này
                    InkWell(
                      onTap: () => _onSettleSingleDebt(debt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Gạch nợ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Đã trả', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
