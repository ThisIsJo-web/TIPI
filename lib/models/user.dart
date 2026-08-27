class User {
  final String id;
  final String email;
  final String name;
  final double budgetGoal;
  final String activeSince;
  final int runsCompleted;
  final double totalSaved;
  final String language;
  final String? preferredProvince;
  final String? preferredMarket;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.budgetGoal,
    required this.activeSince,
    required this.runsCompleted,
    required this.totalSaved,
    required this.language,
    this.preferredProvince,
    this.preferredMarket,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      budgetGoal: (json['budgetGoal'] ?? json['budget_goal'] ?? 0.0).toDouble(),
      activeSince: json['activeSince'] ?? json['active_since'] ?? '',
      runsCompleted: json['runsCompleted'] ?? json['runs_completed'] ?? 0,
      totalSaved: (json['totalSaved'] ?? json['total_saved'] ?? 0.0).toDouble(),
      language: json['language'] ?? 'English',
      preferredProvince: json['preferredProvince'] ?? json['preferred_province'],
      preferredMarket: json['preferredMarket'] ?? json['preferred_market'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'budget_goal': budgetGoal,
      'active_since': activeSince,
      'runs_completed': runsCompleted,
      'total_saved': totalSaved,
      'language': language,
      'preferred_province': preferredProvince,
      'preferred_market': preferredMarket,
    };
  }
}
