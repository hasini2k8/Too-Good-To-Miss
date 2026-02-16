class Deal {
  final String id;
  final String startupId;
  final String startupName;
  final String title;
  final String description;
  final String code;
  final int discountPercentage;
  final String validFrom;
  final String validUntil;
  final String terms;

  Deal({
    required this.id,
    required this.startupId,
    required this.startupName,
    required this.title,
    required this.description,
    required this.code,
    required this.discountPercentage,
    required this.validFrom,
    required this.validUntil,
    required this.terms,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id']?.toString() ?? '',
      startupId: json['startup_id']?.toString() ?? json['startupId']?.toString() ?? '',
      startupName: json['startup_name']?.toString() ?? json['startupName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      discountPercentage: _parseDiscount(json['discount_percentage']),
      validFrom: json['valid_from']?.toString() ?? json['validFrom']?.toString() ?? '',
      validUntil: json['valid_until']?.toString() ?? json['validUntil']?.toString() ?? '',
      terms: json['terms']?.toString() ?? '',
    );
  }

  static int _parseDiscount(dynamic discount) {
    if (discount == null) return 0;
    if (discount is int) return discount;
    if (discount is double) return discount.toInt();
    if (discount is String) return int.tryParse(discount) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startup_id': startupId,
      'startup_name': startupName,
      'title': title,
      'description': description,
      'code': code,
      'discount_percentage': discountPercentage,
      'valid_from': validFrom,
      'valid_until': validUntil,
      'terms': terms,
    };
  }

  // Check if deal is currently valid
  bool isValid() {
    try {
      final now = DateTime.now();
      final from = DateTime.parse(validFrom);
      final until = DateTime.parse(validUntil);
      return now.isAfter(from) && now.isBefore(until.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }

  // Get formatted date string
  String getFormattedValidUntil() {
    try {
      final date = DateTime.parse(validUntil);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return validUntil;
    }
  }

  // Get days remaining
  int getDaysRemaining() {
    try {
      final now = DateTime.now();
      final until = DateTime.parse(validUntil);
      return until.difference(now).inDays;
    } catch (e) {
      return 0;
    }
  }

  // Get discount badge text
  String getDiscountBadge() {
    if (discountPercentage == 0) {
      return 'Special Offer';
    } else if (discountPercentage == 100) {
      return 'FREE';
    } else {
      return '$discountPercentage% OFF';
    }
  }

  // Check if deal is expiring soon (within 7 days)
  bool isExpiringSoon({int daysThreshold = 7}) {
    return isValid() && getDaysRemaining() <= daysThreshold && getDaysRemaining() > 0;
  }

  @override
  String toString() {
    return 'Deal(id: $id, title: $title, startupId: $startupId, discount: $discountPercentage%)';
  }
}