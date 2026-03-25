class Organization {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? logoUrl;
  final double? latitude;
  final double? longitude;
  final int? allowedRadius;

  Organization({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.logoUrl,
    this.latitude,
    this.longitude,
    this.allowedRadius,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      allowedRadius: json['allowedRadius'] is int ? json['allowedRadius'] : (int.tryParse(json['allowedRadius']?.toString() ?? '')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'logoUrl': logoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'allowedRadius': allowedRadius,
    };
  }
}
