/// The structured address the backend parsed out of OCR raw text.
class ParsedAddress {
  const ParsedAddress({
    this.street,
    this.area,
    this.city,
    this.pincode,
    this.complete,
    this.displayText,
  });

  factory ParsedAddress.fromJson(Map<String, dynamic> json) {
    return ParsedAddress(
      street: json['street'] as String?,
      area: json['area'] as String?,
      city: json['city'] as String?,
      pincode: json['pincode'] as String?,
      complete: json['complete'] as String?,
      displayText: json['displayText'] as String?,
    );
  }

  final String? street;
  final String? area;
  final String? city;
  final String? pincode;
  final String? complete;
  final String? displayText;

  String get display =>
      displayText ??
      [street, area, city, pincode]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .join(', ');
}

/// Payload sent to `POST /api/deliveries/manual`.
class ManualAddress {
  const ManualAddress({
    this.orderId,
    this.street,
    this.area,
    this.city,
    this.pincode,
  });

  final String? orderId;
  final String? street;
  final String? area;
  final String? city;
  final String? pincode;

  Map<String, dynamic> toJson() => {
        if (orderId != null) 'orderId': orderId,
        if (street != null) 'street': street,
        if (area != null) 'area': area,
        if (city != null) 'city': city,
        if (pincode != null) 'pincode': pincode,
      };
}
