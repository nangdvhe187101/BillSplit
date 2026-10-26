class BankModel {
  final String bin;
  final String shortName;
  final String fullName;
  final String? logoUrl;
  final bool isSupported;

  BankModel({
    required this.bin,
    required this.shortName,
    required this.fullName,
    this.logoUrl,
    this.isSupported = true,
  });

  factory BankModel.fromJson(Map<String, dynamic> json) {
    return BankModel(
      bin: json['bin'] as String,
      shortName: json['shortName'] as String,
      fullName: json['fullName'] as String,
      logoUrl: json['logoUrl'] as String?,
      isSupported: (json['isSupported'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bin': bin,
      'shortName': shortName,
      'fullName': fullName,
      'logoUrl': logoUrl,
      'isSupported': isSupported,
    };
  }
}
