/// Mirrors the DeliveryDto returned by the backend intake / geocode APIs.
class Parcel {
  const Parcel({
    required this.id,
    this.orderId,
    required this.rawAddress,
    this.latitude,
    this.longitude,
    required this.geocodeStatus,
    this.requiresPinConfirmation = false,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id'] as int,
      orderId: json['orderId'] as String?,
      rawAddress: (json['rawAddress'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geocodeStatus: ParcelGeocodeStatus.fromString(
        (json['geocodeStatus'] as String?) ?? 'NOT_GEOCODED',
      ),
      requiresPinConfirmation: json['requiresPinConfirmation'] as bool? ?? false,
    );
  }

  final int id;
  final String? orderId;
  final String rawAddress;
  final double? latitude;
  final double? longitude;
  final ParcelGeocodeStatus geocodeStatus;
  final bool requiresPinConfirmation;
}

enum ParcelGeocodeStatus {
  notGeocoded,
  autoGeocoded,
  confirmed,
  geocoded,
  failed;

  factory ParcelGeocodeStatus.fromString(String value) {
    return switch (value) {
      'AUTO_GEOCODED' => autoGeocoded,
      'CONFIRMED' => confirmed,
      'GEOCODED' => geocoded,
      'GEOCODING_FAILED' => failed,
      _ => notGeocoded,
    };
  }

  bool get isAmber => this == autoGeocoded;
  bool get isGreen => this == confirmed || this == geocoded;
}
