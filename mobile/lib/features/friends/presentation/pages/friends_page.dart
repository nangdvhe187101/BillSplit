import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/friend_model.dart';
import '../../data/repositories/friend_repository.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _phoneController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  late final FriendRepository _repository;
  List<FriendModel> _friends = [];
  List<FriendModel> _pendingRequests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = FriendRepository(dioClient: context.read<DioClient>());
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friends = await _repository.getFriends();
      final pending = await _repository.getPendingRequests();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _pendingRequests = pending;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách bạn bè. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onAcceptPressed(FriendModel request) async {
    final result = await _repository.acceptRequest(request.friendshipId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    if (result.success) {
      _loadData();
    }
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thêm bạn bè mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập số điện thoại đã đăng ký tài khoản BillSplit:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: 0912345678',
                prefixIcon: Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
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
            onPressed: () async {
              final rawPhone = _phoneController.text.trim();
              final phone = rawPhone.replaceAll(RegExp(r'[\s.-]'), '');
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập số điện thoại'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final result = await _repository.addFriendByPhone(phone);
              if (!context.mounted) return;

              _phoneController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? AppColors.success : AppColors.error,
                ),
              );

              if (result.success) {
                _loadData();
              }
            },
            child: const Text('Kết bạn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bạn bè & Bù trừ nợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        if (_pendingRequests.isNotEmpty) ..._buildPendingSection(),
                        if (_friends.isEmpty && _pendingRequests.isEmpty) _buildEmptyState(),
                        ..._friends.map(_buildFriendCard),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFriendDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm bạn bè', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'Chưa có bạn bè nào. Bấm "Thêm bạn bè" để kết bạn qua số điện thoại.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  List<Widget> _buildPendingSection() {
    return [
      const Text(
        'Lời mời đang chờ',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 10),
      ..._pendingRequests.map((request) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    request.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        request.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _onAcceptPressed(request),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Đồng ý'),
                ),
              ],
            ),
          )),
      const SizedBox(height: 8),
      const Divider(color: AppColors.border),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildFriendCard(FriendModel f) {
    final net = f.netBalance;
    final isOwed = net > 0; // Họ nợ mình
    final isOwing = net < 0; // Mình nợ họ

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySoft.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              f.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  f.phoneNumber,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Nhãn bù trừ công nợ (Net Balance Badge)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isOwed
                    ? '+${_currencyFormat.format(net)} đ'
                    : isOwing
                        ? '${_currencyFormat.format(net)} đ'
                        : '0 đ',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isOwed
                      ? AppColors.success
                      : isOwing
                          ? AppColors.error
                          : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOwed
                    ? 'Cần thu'
                    : isOwing
                        ? 'Cần trả'
                        : 'Sòng phẳng',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isOwed
                      ? AppColors.success
                      : isOwing
                          ? AppColors.error
                          : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
