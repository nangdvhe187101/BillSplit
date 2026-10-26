/// Model đại diện cho một dòng món ăn được quét ra từ ảnh hóa đơn (OCR).
/// Người dùng có thể sửa tên/giá trước khi gán cho người chia bill.
class BillLineItem {
  final String id;
  String name;
  double price;

  /// Danh sách id của SplitMember được gán cho món này.
  /// Rỗng = chưa gán. Nhiều id = món ăn chung của nhiều người cụ thể.
  List<String> assignedMemberIds;

  /// true: món này tính vào quỹ ăn chung (chia đều cho người tham gia ăn chung)
  /// false: món riêng, chỉ tính cho người trong assignedMemberIds
  bool isShared;

  BillLineItem({
    required this.id,
    required this.name,
    required this.price,
    List<String>? assignedMemberIds,
    this.isShared = false,
  }) : assignedMemberIds = assignedMemberIds ?? [];
}
