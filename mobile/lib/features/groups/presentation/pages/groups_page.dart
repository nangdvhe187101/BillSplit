import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _groupNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  late final GroupRepository _repository;
  List<GroupModel> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = GroupRepository(dioClient: context.read<DioClient>());
    _loadGroups();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _repository.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách nhóm. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tạo nhóm chia tiền mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập tên nhóm (ví dụ: Hội ăn trưa, Chuyến đi Đà Lạt):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _groupNameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tên nhóm...',
                prefixIcon: Icon(Icons.group_add_outlined, color: AppColors.primary),
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
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;

              final result = await _repository.createGroup(name: name, category: 'Food');
              if (!context.mounted) return;

              _groupNameController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? AppColors.success : AppColors.error,
                ),
              );

              if (result.success) {
                _loadGroups();
              }
            },
            child: const Text('Tạo nhóm'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nhập mã mời vào nhóm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập mã 6 ký tự được trưởng nhóm chia sẻ:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inviteCodeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: KTX302',
                prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.primary),
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
              final code = _inviteCodeController.text.trim().toUpperCase();
              if (code.isEmpty) return;

              final result = await _repository.joinByInviteCode(code);
              if (!context.mounted) return;

              _inviteCodeController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? AppColors.success : AppColors.error,
                ),
              );

              if (result.success) {
                _loadGroups();
              }
            },
            child: const Text('Vào nhóm'),
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
        title: const Text('Nhóm chia tiền'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded, color: AppColors.primary),
            tooltip: 'Nhập mã mời',
            onPressed: _showJoinGroupDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? _buildErrorState()
                : _groups.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadGroups,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: _groups.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildGroupCard(_groups[index]),
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('Tạo nhóm mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
          ElevatedButton(onPressed: _loadGroups, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Chưa có nhóm nào. Bấm "Tạo nhóm mới" hoặc nhập mã mời để tham gia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildGroupCard(GroupModel g) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySoft.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Mã: ${g.inviteCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${g.memberCount} thành viên',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
