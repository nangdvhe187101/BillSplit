import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../bank/data/models/bank_model.dart';
import '../../../bank/presentation/widgets/bank_picker_bottom_sheet.dart';
import '../bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _accountNameController = TextEditingController();

  BankModel? _selectedBank;
  List<BankModel> _availableBanks = [];
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final dioClient = context.read<DioClient>();
      final response = await dioClient.dio.get('/banks');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((e) => BankModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _availableBanks = list;
          // Mặc định chọn ngân hàng đầu tiên nếu có
          if (_availableBanks.isNotEmpty) {
            _selectedBank = _availableBanks.firstWhere(
              (b) => b.shortName == 'MBBank' || b.shortName == 'TPBank',
              orElse: () => _availableBanks.first,
            );
          }
        });
      }
    } catch (_) {
      // Fallback danh sách mặc định nếu server chưa mở
      setState(() {
        _availableBanks = [
          BankModel(bin: '970422', shortName: 'MBBank', fullName: 'Ngân hàng TMCP Quân đội'),
          BankModel(bin: '970423', shortName: 'TPBank', fullName: 'Ngân hàng TMCP Tiên Phong'),
          BankModel(bin: '970436', shortName: 'Vietcombank', fullName: 'Ngân hàng TMCP Ngoại thương VN'),
          BankModel(bin: '970407', shortName: 'Techcombank', fullName: 'Ngân hàng TMCP Kỹ thương VN'),
        ];
        _selectedBank = _availableBanks.first;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngân hàng nhận tiền'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthRegisterSubmitted(
              phoneNumber: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _fullNameController.text.trim(),
              bankBin: _selectedBank!.bin,
              bankAccountNo: _accountNoController.text.trim(),
              bankAccountName: _accountNameController.text.trim().toUpperCase(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản mới'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is Authenticated) {
            context.go('/home');
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PHẦN 1: THÔNG TIN TÀI KHOẢN
                    _buildSectionCard(
                      title: '1. Thông tin cá nhân & Đăng nhập',
                      icon: Icons.person_rounded,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên hiển thị',
                            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập họ và tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại (dùng làm ID kết bạn)',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập số điện thoại';
                            }
                            final regex = RegExp(r'^(0[3|5|7|8|9])+([0-9]{8})$');
                            if (!regex.hasMatch(val.trim())) {
                              return 'Số điện thoại không đúng định dạng VN (10 số)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập email';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu (tối thiểu 6 ký tự)',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // PHẦN 2: THÔNG TIN TÀI KHOẢN NGÂN HÀNG (VIETQR)
                    _buildSectionCard(
                      title: '2. Tài khoản ngân hàng nhận tiền',
                      icon: Icons.account_balance_rounded,
                      children: [
                        // Chọn ngân hàng
                        InkWell(
                          onTap: () {
                            BankPickerBottomSheet.show(
                              context: context,
                              banks: _availableBanks,
                              onSelect: (bank) {
                                setState(() {
                                  _selectedBank = bank;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ngân hàng thụ hưởng',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedBank != null
                                            ? '${_selectedBank!.shortName} - ${_selectedBank!.fullName}'
                                            : 'Bấm để chọn ngân hàng',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Số tài khoản
                        TextFormField(
                          controller: _accountNoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số tài khoản ngân hàng',
                            prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.primary),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập số tài khoản';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Tên chủ tài khoản
                        TextFormField(
                          controller: _accountNameController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Tên chủ thẻ (IN HOA KHÔNG DẤU)',
                            hintText: 'NGUYEN VAN A',
                            prefixIcon: Icon(Icons.person_pin_rounded, color: AppColors.primary),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập tên chủ tài khoản';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Nút Đăng ký
                    ElevatedButton(
                      onPressed: isLoading ? null : _onRegisterPressed,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Hoàn tất đăng ký'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySoft.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
