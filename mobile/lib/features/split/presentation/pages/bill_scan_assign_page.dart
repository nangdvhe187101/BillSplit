import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/bill_line_item_model.dart';
import '../../data/models/split_member_model.dart';
import '../../data/utils/bill_ocr_parser.dart';

/// Kết quả trả về cho SplitBillPage sau khi người dùng gán xong các món.
class BillScanResult {
  final double totalAmount;
  final List<SplitMember> members; // Đã cập nhật personalAmount theo món riêng
  final String? billTitle;
  final double subtotal;
  final double vat;
  final double discount;

  BillScanResult({
    required this.totalAmount,
    required this.members,
    this.billTitle,
    this.subtotal = 0.0,
    this.vat = 0.0,
    this.discount = 0.0,
  });
}

/// Màn hình quét ảnh hóa đơn bằng Google ML Kit (chạy offline trên máy) và
/// gán nhanh từng món cho người chia bill hoặc vào quỹ ăn chung.
class BillScanAssignPage extends StatefulWidget {
  final File imageFile;
  final List<SplitMember> members;

  const BillScanAssignPage({
    super.key,
    required this.imageFile,
    required this.members,
  });

  @override
  State<BillScanAssignPage> createState() => _BillScanAssignPageState();
}

class _BillScanAssignPageState extends State<BillScanAssignPage> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isScanning = true;
  String? _errorMessage;
  List<BillLineItem> _items = [];
  double _billTotalAmount = 0.0;
  double _subtotal = 0.0;
  double _vat = 0.0;
  double _discount = 0.0;
  String? _billTitle;

  @override
  void initState() {
    super.initState();
    _runOcr();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _runOcr() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final inputImage = InputImage.fromFile(widget.imageFile);
      final result = await _textRecognizer.processImage(inputImage);
      final parsed = BillOcrParser.parseFromRecognizedText(result);

      if (parsed.items.isEmpty && parsed.totalAmount <= 0) {
        setState(() {
          _errorMessage =
              'Không nhận diện được món ăn nào từ ảnh. Vui lòng chụp rõ hơn hoặc thêm món bằng tay.';
          _items = [];
          _billTotalAmount = 0.0;
        });
      } else {
        setState(() {
          _items = parsed.items;
          _billTotalAmount = parsed.totalAmount;
          _subtotal = parsed.subtotal;
          _vat = parsed.vat;
          _discount = parsed.discount;
          _billTitle = parsed.billTitle;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi quét ảnh: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  double get _effectiveTotalAmount {
    if (_billTotalAmount > 0) {
      return _billTotalAmount;
    }
    return _items.fold(0.0, (sum, item) => sum + item.price);
  }

  void _showEditTotalDialog() {
    final controller = TextEditingController(
      text: _effectiveTotalAmount > 0 ? _effectiveTotalAmount.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sửa tổng tiền hóa đơn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập số tiền Tổng cộng thực tế ghi trên hóa đơn (bao gồm cả VAT/phụ phí nếu có):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tổng tiền (VNĐ)',
                suffixText: 'đ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
              if (val > 0) {
                setState(() {
                  _billTotalAmount = val;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _addManualItem() {
    setState(() {
      _items.add(
        BillLineItem(
          id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
          name: '',
          price: 0,
        ),
      );
    });
  }

  void _removeItem(BillLineItem item) {
    setState(() {
      _items.remove(item);
    });
  }

  void _editItem(BillLineItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.price > 0 ? item.price.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sửa món ăn', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên món'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá tiền (VNĐ)', suffixText: 'đ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.name = nameController.text.trim().isEmpty ? 'Món ăn' : nameController.text.trim();
                item.price = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
              });
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // Chạm chip để gán/bỏ gán món cho một thành viên cụ thể (món riêng)
  void _toggleAssignMember(BillLineItem item, SplitMember member) {
    setState(() {
      item.isShared = false;
      if (item.assignedMemberIds.contains(member.id)) {
        item.assignedMemberIds.remove(member.id);
      } else {
        item.assignedMemberIds.add(member.id);
      }
    });
  }

  // Chạm chip "Ăn chung" để đưa món vào quỹ chung chia đều cho người tham gia ăn chung
  void _toggleShared(BillLineItem item) {
    setState(() {
      item.isShared = !item.isShared;
      if (item.isShared) {
        item.assignedMemberIds.clear();
      }
    });
  }

  bool get _allItemsAssigned {
    if (_items.isEmpty) return false;
    return _items.every((item) => item.isShared || item.assignedMemberIds.isNotEmpty);
  }

  void _onConfirmPressed() {
    if (!_allItemsAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng gán tất cả món cho người ăn hoặc chọn "Ăn chung"'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Reset trạng thái món riêng cũ trước khi cộng lại từ danh sách món vừa gán
    for (final member in widget.members) {
      member.personalAmount = 0.0;
      member.personalNote = null;
      member.participatesShared = true;
    }

    final sharedNotes = <String>[];
    for (final item in _items) {
      if (item.isShared) {
        sharedNotes.add(item.name);
        continue;
      }
      // Món riêng: chia đều giá món cho đúng những người được gán (ví dụ 1 đĩa quẩy riêng 2 người ăn)
      final perPersonPrice = item.price / item.assignedMemberIds.length;
      for (final memberId in item.assignedMemberIds) {
        final member = widget.members.firstWhere((m) => m.id == memberId);
        member.personalAmount += perPersonPrice;
        member.personalNote = member.personalNote == null
            ? item.name
            : '${member.personalNote}, ${item.name}';
      }
    }

    Navigator.pop(
      context,
      BillScanResult(
        totalAmount: _effectiveTotalAmount,
        members: widget.members,
        billTitle: _billTitle,
        subtotal: _subtotal,
        vat: _vat,
        discount: _discount,
      ),
    );
  }

  Widget _buildTotalSection() {
    final sumItems = _items.fold(0.0, (sum, it) => sum + it.price);
    final hasTaxOrDiff = (_effectiveTotalAmount - sumItems).abs() > 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'TỔNG TIỀN HÓA ĐƠN (CẦN CHIA)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currencyFormat.format(_effectiveTotalAmount)} đ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarker,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: _showEditTotalDialog,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Sửa tổng tiền',
              ),
            ],
          ),
          if (hasTaxOrDiff) ...[
            const Divider(color: AppColors.primaryLight, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng tiền ${_items.length} món: ${_currencyFormat.format(sumItems)} đ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  _effectiveTotalAmount > sumItems
                      ? 'Thuế/Phụ phí: +${_currencyFormat.format(_effectiveTotalAmount - sumItems)} đ'
                      : 'Giảm giá: -${_currencyFormat.format(sumItems - _effectiveTotalAmount)} đ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _effectiveTotalAmount > sumItems ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quét hóa đơn & Gán món'),
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Đang quét hóa đơn trên máy (offline)...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(widget.imageFile, height: 160, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 16),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Thẻ hiển thị TỔNG TIỀN HÓA ĐƠN thực tế
                          _buildTotalSection(),

                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Món ăn nhận diện (${_items.length} món)',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              Text(
                                '${_currencyFormat.format(_items.fold(0.0, (sum, it) => sum + it.price))} đ',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chạm chip tên người để gán món riêng, hoặc chọn "Ăn chung" để chia đều cho cả nhóm.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ..._items.map((item) => _buildItemCard(item)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _addManualItem,
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            label: const Text('Thêm món bằng tay'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                    child: ElevatedButton(
                      onPressed: _items.isEmpty ? null : _onConfirmPressed,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Áp dụng vào bill'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemCard(BillLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _editItem(item),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name.isEmpty ? 'Chạm để nhập tên món' : item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: item.name.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_currencyFormat.format(item.price)} đ',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                onPressed: () => _removeItem(item),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.members.map((member) {
                final selected = item.assignedMemberIds.contains(member.id);
                return ChoiceChip(
                  label: Text(member.isPayer ? 'Bạn' : member.name.split(' ').first),
                  selected: selected,
                  onSelected: (_) => _toggleAssignMember(item, member),
                  selectedColor: AppColors.primarySoft,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primaryDark : AppColors.textSecondary,
                  ),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                );
              }),
              ChoiceChip(
                label: const Text('Ăn chung cả nhóm'),
                selected: item.isShared,
                onSelected: (_) => _toggleShared(item),
                selectedColor: const Color(0xFFD1FAE5),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.isShared ? const Color(0xFF047857) : AppColors.textSecondary,
                ),
                side: BorderSide(color: item.isShared ? AppColors.success : AppColors.border),
                avatar: Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: item.isShared ? const Color(0xFF047857) : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
