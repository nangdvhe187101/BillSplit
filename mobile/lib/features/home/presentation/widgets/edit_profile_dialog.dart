import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../bank/data/models/bank_model.dart';
import '../../data/repositories/profile_repository.dart';

class EditProfileDialog extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileDialog({super.key, required this.currentUser});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _accountNoController;
  late final TextEditingController _accountNameController;

  late final ProfileRepository _profileRepository;
  late final DioClient _dioClient;

  List<BankModel> _banks = [];
  String? _selectedBankBin;
  bool _isLoading = false;
  bool _isLoadingBanks = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.fullName);
    _accountNoController = TextEditingController(text: widget.currentUser.bankAccountNo);
    _accountNameController = TextEditingController(text: widget.currentUser.bankAccountName);
    _selectedBankBin = widget.currentUser.bankBin;

    _dioClient = context.read<DioClient>();
    _profileRepository = ProfileRepository(
      dioClient: _dioClient,
      localStorage: context.read<LocalStorageService>(),
    );

    _loadBanks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final response = await _dioClient.dio.get('/banks');
      if (response.statusCode == 200 && response.data is List) {
        final banks = (response.data as List)
            .map((e) => BankModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _banks = banks;
          _isLoadingBanks = false;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoadingBanks = false;
    });
  }

  Future<void> _onSavePressed() async {
    final name = _nameController.text.trim();
    final accountNo = _accountNoController.text.trim();
    final accountName = _accountNameController.text.trim().toUpperCase();

    if (name.isEmpty || accountNo.isEmpty || accountName.isEmpty || _selectedBankBin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin hồ sơ và tài khoản ngân hàng.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _profileRepository.updateProfile(
      fullName: name,
      bankBin: _selectedBankBin!,
      bankAccountNo: accountNo,
      bankAccountName: accountName,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      // Cập nhật AuthBloc với thông tin mới
      final token = await context.read<LocalStorageService>().getToken();
      if (mounted && token != null) {
        context.read<AuthBloc>().add(AuthCheckRequested());
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cập nhật hồ sơ & Ngân hàng',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Họ và tên
            const Text(
              'Họ và tên',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Nhập họ và tên...',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            // Ngân hàng VietQR
            const Text(
              'Ngân hàng nhận tiền (VietQR)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            _isLoadingBanks
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _banks.any((b) => b.bin == _selectedBankBin) ? _selectedBankBin : null,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_outlined, color: AppColors.primary),
                    ),
                    hint: const Text('Chọn ngân hàng...'),
                    items: _banks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank.bin,
                        child: Text(
                          '${bank.shortName} (${bank.bin})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBankBin = val;
                      });
                    },
                  ),
            const SizedBox(height: 16),
            // Số tài khoản ngân hàng
            const Text(
              'Số tài khoản ngân hàng',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _accountNoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nhập số tài khoản...',
                prefixIcon: Icon(Icons.credit_card_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            // Tên chủ tài khoản
            const Text(
              'Tên chủ tài khoản (In hoa không dấu)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _accountNameController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'NGUYEN VAN A',
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _onSavePressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu thông tin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
