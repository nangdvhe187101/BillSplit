import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/split_member_model.dart';
import '../../data/repositories/debt_repository.dart';
import 'bill_scan_assign_page.dart';

class SplitBillPage extends StatefulWidget {
  final double? initialAmount;
  final String? initialTitle;

  const SplitBillPage({
    super.key,
    this.initialAmount,
    this.initialTitle,
  });

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customNameController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  // Danh sách những người tham gia chia bill (luôn bao gồm bản thân ở vị trí đầu tiên)
  final List<SplitMember> _members = [];
  bool _isEqualSplit = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toInt().toString();
    }

    // 1. Thêm bản thân (Chủ bill / Người trả tiền)
    _members.add(
      SplitMember(
        id: 'self',
        name: 'Bạn (Người trả tiền)',
        isAppUser: true,
        isPayer: true,
      ),
    );

    // 2. Mẫu sẵn 2 bạn bè cùng chia bill để trải nghiệm
    _members.addAll([
      SplitMember(
        id: 'friend-1',
        name: 'Trần Văn B (Bạn cùng phòng)',
        phoneNumber: '0987654321',
        isAppUser: true,
      ),
      SplitMember(
        id: 'friend-2',
        name: 'Lê Thị C (Nhóm đồ án)',
        phoneNumber: '0911223344',
        isAppUser: true,
      ),
    ]);

    _recalculateSmartSplit();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final clean = _amountController.text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0.0;
  }

  // Kiểm tra id có đúng định dạng Guid (36 ký tự, có dấu gạch ngang) để biết đây là
  // user thật lấy từ Backend hay chỉ là id demo cục bộ (ví dụ "friend-1", "self").
  static final RegExp _guidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  bool _isValidGuid(String id) => _guidRegex.hasMatch(id);

  // Chụp ảnh/chọn ảnh hóa đơn, quét OCR offline bằng ML Kit rồi gán món cho từng người
  Future<void> _onScanBillPressed() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Chụp ảnh hóa đơn'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null || !mounted) return;

    final result = await Navigator.push<BillScanResult>(
      context,
      MaterialPageRoute(
        builder: (context) => BillScanAssignPage(
          imageFile: File(pickedFile.path),
          members: _members,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _amountController.text = result.totalAmount.toInt().toString();
      if (result.billTitle != null && result.billTitle!.isNotEmpty && _titleController.text.trim().isEmpty) {
        _titleController.text = result.billTitle!;
      }
      _recalculateSmartSplit();
    });
  }

  double get _sumMembersAmount {
    return _members.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _difference {
    return _totalAmount - _sumMembersAmount;
  }

  // Tiền của bản thân tự trả
  double get _myShare {
    final payer = _members.firstWhere((m) => m.isPayer, orElse: () => _members.first);
    return payer.amount;
  }

  // Tổng tiền cần thu từ những người nợ khác
  double get _toCollectAmount {
    return _members.where((m) => !m.isPayer).fold(0.0, (sum, item) => sum + item.amount);
  }

  // Thuật toán chia thông minh: Tự động tách "Món riêng" và chia đều "Quỹ ăn chung"
  void _recalculateSmartSplit() {
    if (!_isEqualSplit || _members.isEmpty || _totalAmount <= 0) return;

    // 1. Tổng tiền món riêng của tất cả mọi người
    final totalPersonal = _members.fold(0.0, (sum, m) => sum + m.personalAmount);

    // 2. Quỹ ăn chung còn lại sau khi trừ món riêng
    final sharedPool = _totalAmount - totalPersonal;

    // 3. Danh sách người có tham gia ăn chung
    final sharedMembers = _members.where((m) => m.participatesShared).toList();
    final sharedCount = sharedMembers.length;

    if (sharedCount > 0 && sharedPool >= 0) {
      final baseShared = (sharedPool / sharedCount).floorToDouble();
      final remainder = sharedPool - (baseShared * sharedCount);

      for (int i = 0; i < _members.length; i++) {
        final m = _members[i];
        if (m.participatesShared) {
          // Người đầu tiên trong nhóm ăn chung nhận phần dư làm tròn
          final isFirstShared = sharedMembers.indexOf(m) == 0;
          final mySharedPart = isFirstShared ? (baseShared + remainder) : baseShared;
          m.amount = mySharedPart + m.personalAmount;
        } else {
          // Người không ăn chung chỉ trả đúng tiền món riêng của họ
          m.amount = m.personalAmount;
        }
      }
    } else {
      // Trường hợp tổng món riêng vượt quá hóa đơn hoặc không ai ăn chung
      for (final m in _members) {
        m.amount = m.personalAmount;
      }
    }

    setState(() {});
  }

  void _addCustomMember() {
    final name = _customNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _members.add(
        SplitMember(
          id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          isAppUser: false,
        ),
      );
      _customNameController.clear();
      if (_isEqualSplit) {
        _recalculateSmartSplit();
      }
    });
    Navigator.pop(context);
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Thêm người chia bill',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập tên bạn bè hoặc khách ngoài cùng ăn/chi tiêu:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customNameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Anh Nam Grab, Tuấn bạn mới...',
                prefixIcon: Icon(Icons.person_add_outlined, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: _addCustomMember,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Thêm vào bill'),
          ),
        ],
      ),
    );
  }

  // Dialog nhập món riêng cho từng người
  void _showPersonalItemDialog(SplitMember member) {
    final noteController = TextEditingController(text: member.personalNote ?? '');
    final priceController = TextEditingController(
      text: member.personalAmount > 0 ? member.personalAmount.toInt().toString() : '',
    );
    bool participatesShared = member.participatesShared;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Món riêng của ${member.name}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dành cho trường hợp bạn này gọi món riêng (nước ép, bia, đồ ăn thêm...) không ăn chung cả nhóm.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Tên món riêng (ví dụ: Nước ép cam, Bia lon)',
                  prefixIcon: Icon(Icons.local_cafe_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá tiền món riêng (VNĐ)',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.primary),
                  suffixText: 'đ',
                ),
              ),
              const SizedBox(height: 14),
              // Switch: Bạn này có ăn chung phần thức ăn nhóm không?
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Có tham gia ăn chung cả nhóm?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  participatesShared ? 'Được chia đều quỹ ăn chung' : 'Chỉ trả tiền món riêng, không chia quỹ chung',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                value: participatesShared,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  setDialogState(() {
                    participatesShared = val;
                  });
                },
              ),
            ],
          ),
          actions: [
            if (member.personalAmount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    member.personalAmount = 0.0;
                    member.personalNote = null;
                    member.participatesShared = true;
                    if (_isEqualSplit) _recalculateSmartSplit();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Xóa món riêng', style: TextStyle(color: AppColors.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
                setState(() {
                  member.personalAmount = price;
                  member.personalNote = noteController.text.trim();
                  member.participatesShared = participatesShared;
                  if (_isEqualSplit) _recalculateSmartSplit();
                });
                Navigator.pop(context);
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSavePressed() async {
    final debtors = _members.where((m) => !m.isPayer && m.amount > 0).toList();

    if (debtors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất 1 người nợ để chia tiền'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_difference.abs() > 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Số tiền các phần chưa khớp với tổng hóa đơn (chênh lệch: ${_currencyFormat.format(_difference)} đ)',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    // Chỉ gửi lên Backend những người THỰC SỰ nợ (bỏ qua payer vì payer không tự nợ mình).
    // Backend yêu cầu debtorId phải là Guid hợp lệ của user có thật trong hệ thống;
    // id dạng demo cục bộ (ví dụ "friend-1") được coi như khách ngoài (customDebtorName)
    // để không gửi lên một Guid giả gây lỗi 400 ở Backend.
    final debtsPayload = debtors
        .map((m) => {
              'debtorId': (m.isAppUser && _isValidGuid(m.id)) ? m.id : null,
              'customDebtorName': (m.isAppUser && _isValidGuid(m.id)) ? null : m.name,
              'amount': m.amount,
            })
        .toList();

    final dioClient = context.read<DioClient>();
    final repository = DebtRepository(dioClient: dioClient);
    final result = await repository.splitExpense(
      title: _titleController.text.trim(),
      // Backend yêu cầu totalAmount khớp đúng tổng các khoản nợ gửi lên (debts),
      // không phải tổng hóa đơn gốc: phần payer tự trả không nằm trong debts nên
      // không được tính vào totalAmount ở request này.
      totalAmount: _toCollectAmount,
      category: 'Food',
      debts: debtsPayload,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.success || result.debts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã tạo bill chia cho ${_members.length} người! Phần bạn: ${_currencyFormat.format(_myShare)} đ',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    final firstDebt = result.debts.first;
    final debtsCount = result.debts.length;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Tạo bill chia nợ thành công!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Đã ghi nhận $debtsCount khoản nợ. Hệ thống đã tự động cộng dồn công nợ cho từng thành viên.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              // Nút 1: Quay lại trang chủ và load lại hệ thống để đồng bộ lại dữ liệu
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home', extra: {'refresh': true});
                },
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                label: const Text(
                  'Quay lại trang chủ & Đồng bộ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              // Nút 2: Xem mã VietQR thu tiền của người đầu tiên
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(
                    '/qr-payment',
                    extra: {
                      'debtId': firstDebt.id,
                      'debtorName': firstDebt.debtorName,
                      'amount': firstDebt.amount,
                      'debtCode': firstDebt.debtCode,
                      'title': _titleController.text.trim(),
                    },
                  );
                },
                icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                label: Text(
                  'Xem VietQR thu tiền (${firstDebt.debtorName})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 6),
              // Nút 3: Xem Sổ nợ gộp theo người
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/person-debts');
                },
                icon: const Icon(Icons.people_alt_outlined, color: AppColors.textSecondary, size: 18),
                label: const Text(
                  'Xem Sổ nợ gộp theo người',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDifferenceZero = _difference.abs() <= 1.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tạo bill & Chia tiền'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // THẺ NHẬP THÔNG TIN HÓA ĐƠN
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primarySoft.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin hóa đơn chi tiêu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _onScanBillPressed,
                              icon: const Icon(Icons.document_scanner_outlined, color: AppColors.primary),
                              label: const Text('Chụp ảnh hóa đơn để tính nhanh'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Nội dung chi tiêu (ví dụ: Ăn trưa Haidilao)',
                                prefixIcon: Icon(Icons.restaurant_rounded, color: AppColors.primary),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Vui lòng nhập tên hóa đơn';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _recalculateSmartSplit(),
                              decoration: const InputDecoration(
                                labelText: 'Tổng số tiền thanh toán (VNĐ)',
                                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                                suffixText: 'đ',
                                suffixStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Vui lòng nhập tổng số tiền';
                                }
                                if (_totalAmount <= 0) {
                                  return 'Số tiền phải lớn hơn 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // KHU VỰC CẤU HÌNH CHIA TIỀN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Thành viên chia bill',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_members.length} người',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Switch Chia đều thông minh
                          Row(
                            children: [
                              Text(
                                _isEqualSplit ? 'Tự động' : 'Tùy chỉnh',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Switch(
                                value: _isEqualSplit,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _isEqualSplit = val;
                                    if (_isEqualSplit) {
                                      _recalculateSmartSplit();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // DANH SÁCH THÀNH VIÊN CHIA (Hỗ trợ món riêng)
                      ..._members.map((member) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: member.isPayer
                                ? AppColors.primarySoft.withValues(alpha: 0.3)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: member.isPayer ? AppColors.primary : AppColors.border,
                              width: member.isPayer ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: member.isPayer
                                        ? AppColors.primary
                                        : (member.isAppUser ? AppColors.primarySoft : Colors.grey.shade200),
                                    child: Icon(
                                      member.isPayer
                                          ? Icons.star_rounded
                                          : (member.isAppUser ? Icons.person : Icons.person_outline),
                                      color: member.isPayer
                                          ? Colors.white
                                          : (member.isAppUser ? AppColors.primary : AppColors.textSecondary),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: member.isPayer ? AppColors.primaryDark : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          member.isPayer
                                              ? 'Chủ bill • Đã trả trước'
                                              : (member.isAppUser ? 'Người dùng app' : 'Khách ngoài'),
                                          style: TextStyle(
                                            color: member.isPayer ? AppColors.primary : AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: member.isPayer ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Hiển thị số tiền
                                  if (_isEqualSplit)
                                    Text(
                                      '${_currencyFormat.format(member.amount)} đ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: member.isPayer ? AppColors.primaryDark : AppColors.textPrimary,
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: member.amount.toInt().toString(),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.end,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          suffixText: 'đ',
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            member.amount = double.tryParse(val) ?? 0.0;
                                          });
                                        },
                                      ),
                                    ),
                                  // Nút xóa (Không cho phép xóa chính mình khỏi bill)
                                  if (!member.isPayer)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _members.remove(member);
                                          if (_isEqualSplit) {
                                            _recalculateSmartSplit();
                                          }
                                        });
                                      },
                                    )
                                  else
                                    const SizedBox(width: 40),
                                ],
                              ),
                              const Divider(height: 16, color: AppColors.border),

                              // Khu vực Món riêng & Trạng thái Ăn chung
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Hiển thị badge món riêng nếu có
                                  if (member.personalAmount > 0)
                                    InkWell(
                                      onTap: () => _showPersonalItemDialog(member),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.local_cafe_rounded, size: 13, color: Color(0xFFD97706)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${member.personalNote ?? "Món riêng"}: +${_currencyFormat.format(member.personalAmount)} đ',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      member.participatesShared ? 'Ăn chung quỹ nhóm' : 'Không ăn chung',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: member.participatesShared ? AppColors.textSecondary : AppColors.error,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),

                                  // Nút bấm gán món riêng
                                  TextButton.icon(
                                    onPressed: () => _showPersonalItemDialog(member),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(
                                      member.personalAmount > 0 ? Icons.edit_outlined : Icons.add_circle_outline,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(
                                      member.personalAmount > 0 ? 'Sửa món riêng' : '+ Món riêng',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Nút Thêm Người Ngoài / Bạn Bè
                      OutlinedButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        label: const Text('Thêm người ngoài / Bạn bè'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // THANH TỔNG KẾT & NÚT LƯU Ở DƯỚI CÙNG
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Hàng chi tiết: Phần bạn tự trả
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('Phần bạn tự trả:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                      Text(
                        '${_currencyFormat.format(_myShare)} đ',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Hàng chi tiết: Cần thu từ bạn bè
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Cần thu về (${_members.length - 1} người):',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '${_currencyFormat.format(_toCollectAmount)} đ',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success),
                      ),
                    ],
                  ),
                  const Divider(height: 18, color: AppColors.border),

                  // Hàng Tổng Phân Bổ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng phân bổ:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '${_currencyFormat.format(_sumMembersAmount)} / ${_currencyFormat.format(_totalAmount)} đ',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                  if (!isDifferenceZero) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chênh lệch:',
                          style: TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                        Text(
                          '${_difference > 0 ? "+" : ""}${_currencyFormat.format(_difference)} đ',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: (isDifferenceZero && !_isSaving) ? _onSavePressed : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Lưu bill & Tạo mã thanh toán'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
