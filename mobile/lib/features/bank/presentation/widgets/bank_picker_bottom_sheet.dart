import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/bank_model.dart';

/// BottomSheet chọn ngân hàng thụ hưởng kèm ô tìm kiếm thời gian thực
class BankPickerBottomSheet extends StatefulWidget {
  final List<BankModel> banks;
  final Function(BankModel) onSelect;

  const BankPickerBottomSheet({
    super.key,
    required this.banks,
    required this.onSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required List<BankModel> banks,
    required Function(BankModel) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BankPickerBottomSheet(
        banks: banks,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<BankPickerBottomSheet> createState() => _BankPickerBottomSheetState();
}

class _BankPickerBottomSheetState extends State<BankPickerBottomSheet> {
  late List<BankModel> _filteredBanks;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredBanks = widget.banks;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBanks = widget.banks;
      } else {
        _filteredBanks = widget.banks.where((bank) {
          return bank.shortName.toLowerCase().contains(query) ||
              bank.fullName.toLowerCase().contains(query) ||
              bank.bin.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar kéo
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Tiêu đề
          const Text(
            'Chọn ngân hàng nhận tiền',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Ô tìm kiếm ngân hàng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm ngân hàng (MB, TPB, VCB...)',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Danh sách ngân hàng
          Expanded(
            child: _filteredBanks.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy ngân hàng phù hợp',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredBanks.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final bank = _filteredBanks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryLight, width: 0.5),
                          ),
                          child: bank.logoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: bank.logoUrl!,
                                  placeholder: (context, url) => const Icon(
                                    Icons.account_balance,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.account_balance,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                )
                              : const Icon(Icons.account_balance, color: AppColors.primary),
                        ),
                        title: Text(
                          bank.shortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          bank.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onTap: () {
                          widget.onSelect(bank);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
