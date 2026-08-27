class PriceItem {
  final String date;
  final String admin1;
  final String admin2;
  final String market;
  final int marketId;
  final double latitude;
  final double longitude;
  final String category;
  final String commodity;
  final String unit;
  final String priceflag;
  final String pricetype;
  final String currency;
  final double price;

  PriceItem({
    required this.date,
    required this.admin1,
    required this.admin2,
    required this.market,
    required this.marketId,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.commodity,
    required this.unit,
    required this.priceflag,
    required this.pricetype,
    required this.currency,
    required this.price,
  });

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    return PriceItem(
      date: json['date'] ?? '',
      admin1: json['admin1'] ?? '',
      admin2: json['admin2'] ?? '',
      market: json['market'] ?? '',
      marketId: (json['market_id'] ?? 0).toInt(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      category: json['category'] ?? '',
      commodity: json['commodity'] ?? '',
      unit: json['unit'] ?? '',
      priceflag: json['priceflag'] ?? '',
      pricetype: json['pricetype'] ?? '',
      currency: json['currency'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'admin1': admin1,
      'admin2': admin2,
      'market': market,
      'market_id': marketId,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'commodity': commodity,
      'unit': unit,
      'priceflag': priceflag,
      'pricetype': pricetype,
      'currency': currency,
      'price': price,
    };
  }
}
