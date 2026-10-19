import 'package:cloud_firestore/cloud_firestore.dart';

class BriefingRecord {
  final String id;
  final String sessionCode;
  final String title;
  final int tabType; // 0=초동, 1=중간, 2=공식
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> fields;

  BriefingRecord({
    required this.id,
    required this.sessionCode,
    required this.title,
    required this.tabType,
    required this.createdAt,
    required this.updatedAt,
    required this.fields,
  });

  factory BriefingRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return BriefingRecord(
      id: id,
      sessionCode: data['sessionCode'] as String? ?? '',
      title: data['title'] ?? '',
      tabType: (data['tabType'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fields: Map<String, dynamic>.from(data['fields'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sessionCode': sessionCode,
        'title': title,
        'tabType': tabType,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'fields': fields,
      };
}
