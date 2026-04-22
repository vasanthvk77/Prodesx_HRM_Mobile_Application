class ProfessionalTax {
  final dynamic ptId;
  final String taxName;
  final double fromAmount;
  final double toAmount;
  final double taxAmount;
  final dynamic organizationId;
  final bool isActive;
  final DateTime? createdDateTime;
  final dynamic createdBy;

  const ProfessionalTax({
    this.ptId,
    required this.taxName,
    required this.fromAmount,
    required this.toAmount,
    required this.taxAmount,
    required this.organizationId,
    this.isActive = true,
    this.createdDateTime,
    this.createdBy,
  });

  factory ProfessionalTax.fromJson(Map<String, dynamic> json) {
    return ProfessionalTax(
      ptId: json['ptId'] ?? json['PTId'],
      taxName: json['taxName'] ?? json['TaxName'] ?? '',
      fromAmount: (json['fromAmount'] ?? json['FromAmount'] as num).toDouble(),
      toAmount: (json['toAmount'] ?? json['ToAmount'] as num).toDouble(),
      taxAmount: (json['taxAmount'] ?? json['TaxAmount'] as num).toDouble(),
      organizationId: json['organizationId'] ?? json['OrganizationId'],
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
      createdDateTime: (json['createdDateTime'] ?? json['CreatedDateTime']) != null
          ? DateTime.parse(json['createdDateTime'] ?? json['CreatedDateTime'])
          : null,
      createdBy: json['createdBy'] ?? json['CreatedBy'],
    );
  }

  Map<String, dynamic> toJson() => {
        'ptId': ptId,
        'taxName': taxName,
        'fromAmount': fromAmount,
        'toAmount': toAmount,
        'taxAmount': taxAmount,
        'organizationId': organizationId,
        'isActive': isActive,
      };
}
