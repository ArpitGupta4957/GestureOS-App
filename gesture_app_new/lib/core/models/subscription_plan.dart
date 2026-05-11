class SubscriptionPlan {
  final int id;
  final String name;
  final double price;
  final String currency;
  final int durationDays;
  final List<String> features;
  final String gatewayPlanId;
  final String planType; // TRIAL, PAID
  final Map<String, dynamic> limits;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.features,
    required this.gatewayPlanId,
    required this.planType,
    required this.limits,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    // Issue #16 fix: Validate limits structure
    Map<String, dynamic> limits = {};
    if (json['limits'] != null && json['limits'] is Map) {
      limits = Map<String, dynamic>.from(json['limits'] as Map);
    }

    // Validate that all limit values are numeric
    limits.forEach((key, value) {
      if (value is! int && value is! double) {
        limits[key] = 0; // Default to 0 (unlimited) if invalid
      }
    });

    return SubscriptionPlan(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Unknown Plan',
      price: json['price'] != null
          ? double.tryParse(json['price'].toString()) ?? 0.0
          : 0.0,
      currency: json['currency'] ?? 'INR',
      durationDays: json['duration_days'] is int
          ? json['duration_days']
          : int.tryParse(json['duration_days'].toString()) ?? 30,
      features:
          json['features'] != null ? List<String>.from(json['features']) : [],
      gatewayPlanId: json['gateway_plan_id'] ?? '',
      planType: json['plan_type'] ?? 'PAID',
      limits: limits,
    );
  }
}
