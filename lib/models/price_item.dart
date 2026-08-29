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
    this.date = '',
    this.admin1 = 'Region XI',
    this.admin2 = 'Davao del Norte',
    this.market = '',
    this.marketId = 0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.category = '',
    required this.commodity,
    this.unit = 'kg',
    this.priceflag = '',
    this.pricetype = '',
    this.currency = 'PHP',
    required this.price,
  });

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    return PriceItem(
      date: json['date'] ?? '',
      admin1: json['admin1'] ?? '',
      admin2: json['admin2'] ?? '',
      market: json['market'] ?? '',
      marketId: (json['market_id'] ?? json['marketId'] ?? 0).toInt(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      category: json['category'] ?? '',
      commodity: json['commodity'] ?? '',
      unit: json['unit'] ?? '',
      priceflag: json['priceflag'] ?? '',
      pricetype: json['pricetype'] ?? '',
      currency: json['currency'] ?? '',
      price: _parseDouble(json['price']),
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
