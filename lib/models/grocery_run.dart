import 'grocery_run_item.dart';

class GroceryRun {
  final String id;
  final String userId;
  final String name;
  final double budget;
  final double spent;
  final String status; // 'active', 'completed', 'draft'
  final List<GroceryRunItem> items;
  final DateTime createdAt;

  GroceryRun({
    required this.id,
    required this.userId,
    required this.name,
    required this.budget,
    required this.spent,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  factory GroceryRun.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<GroceryRunItem> parsedItems = itemsList
        .map((i) => GroceryRunItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return GroceryRun(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      name: json['name'] ?? '',
      budget: _parseDouble(json['budget']),
      spent: _parseDouble(json['spent']),
      status: json['status'] ?? 'active',
      items: parsedItems,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'budget': budget,
      'spent': spent,
      'status': status,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
