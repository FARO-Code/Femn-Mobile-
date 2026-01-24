import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionType { oneDay, multiDay }
enum SessionStatus { pending, active, completed, cancelled }

class TherapySession {
  final String id;
  final String therapistId;
  final String clientId;
  final SessionType type;
  final SessionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TimelineItem> timeline;
  final String problemDescription;

  TherapySession({
    required this.id,
    required this.therapistId,
    required this.clientId,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.timeline = const [],
    this.problemDescription = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'therapistId': therapistId,
      'clientId': clientId,
      'type': type.index,
      'status': status.index,
      'startTime': startTime,
      'endTime': endTime,
      'timeline': timeline.map((x) => x.toMap()).toList(),
      'problemDescription': problemDescription,
    };
  }

  factory TherapySession.fromMap(Map<String, dynamic> map, String id) {
    return TherapySession(
      id: id,
      therapistId: map['therapistId'] ?? '',
      clientId: map['clientId'] ?? '',
      type: SessionType.values[map['type'] ?? 0],
      status: SessionStatus.values[map['status'] ?? 0],
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      timeline: List<TimelineItem>.from(
        (map['timeline'] as List? ?? []).map((x) => TimelineItem.fromMap(x)),
      ),
      problemDescription: map['problemDescription'] ?? '',
    );
  }
}

class TimelineItem {
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isCompleted;

  TimelineItem({
    required this.title,
    required this.description,
    required this.timestamp,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'timestamp': timestamp,
      'isCompleted': isCompleted,
    };
  }

  factory TimelineItem.fromMap(Map<String, dynamic> map) {
    return TimelineItem(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class TherapistReview {
  final String id;
  final String therapistId;
  final String reviewerId;
  final double rating;
  final String comment;
  final DateTime timestamp;

  TherapistReview({
    required this.id,
    required this.therapistId,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'therapistId': therapistId,
      'reviewerId': reviewerId,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}

class TherapistReport {
  final String id;
  final String therapistId;
  final String reporterId;
  final String reason;
  final DateTime timestamp;

  TherapistReport({
    required this.id,
    required this.therapistId,
    required this.reporterId,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'therapistId': therapistId,
      'reporterId': reporterId,
      'reason': reason,
      'timestamp': timestamp,
    };
  }
}
