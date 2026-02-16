class Review {
  final String id;
  final String startupId;  // This must match the Startup.id field
  final String username;
  final int rating;
  final String comment;
  final String date;

  Review({
    required this.id,
    required this.startupId,
    required this.username,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      startupId: json['startupId'] as String,  // Parse startupId from JSON
      username: json['reviewer_name'] as String,
      rating: json['rating'] is int 
          ? json['rating'] as int 
          : (json['rating'] as double).toInt(),
      comment: json['comment'] as String,
      date: json['date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startupId': startupId,  // Save startupId to JSON
      'reviewer_name': username,
      'rating': rating,
      'comment': comment,
      'date': date,
    };
  }

  String getFormattedDate() {
    try {
      final dateTime = DateTime.parse(date);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // Helper to create a copy with updated fields
  Review copyWith({
    String? id,
    String? startupId,
    String? username,
    int? rating,
    String? comment,
    String? date,
  }) {
    return Review(
      id: id ?? this.id,
      startupId: startupId ?? this.startupId,
      username: username ?? this.username,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      date: date ?? this.date,
    );
  }

  @override
  String toString() {
    return 'Review(id: $id, startupId: $startupId, username: $username, rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Review && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}