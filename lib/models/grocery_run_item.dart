class GroceryRunItem {
  final String id;
  final String runId;
  final String commodity;
  final double price;
  final double quantity;
  final String unit;
  final String category;
  final String market;
  final bool checked;

  GroceryRunItem({
    required this.id,
    required this.runId,
    required this.commodity,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.market,
    required this.checked,
  });

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  factory GroceryRunItem.fromJson(Map<String, dynamic> json) {
    return GroceryRunItem(
      id: json['id'] ?? '',
      runId: json['runId'] ?? json['run_id'] ?? '',
      commodity: json['commodity'] ?? '',
      price: _parseDouble(json['price']),
      quantity: _parseDouble(json['quantity'] ?? 1.0),
      unit: json['unit'] ?? '',
      category: json['category'] ?? '',
      market: json['market'] ?? '',
      checked: json['checked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'run_id': runId,
      'commodity': commodity,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'market': market,
      'checked': checked,
    };
  }
}
