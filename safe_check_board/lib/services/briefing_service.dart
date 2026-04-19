import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/briefing_record.dart';

class BriefingService {
  static final _col =
      FirebaseFirestore.instance.collection('briefings');

  static Stream<List<BriefingRecord>> stream(String sessionCode) {
    return _col
        .where('sessionCode', isEqualTo: sessionCode)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BriefingRecord.fromFirestore(d.data(), d.id))
            .toList());
  }

  static Future<String> create(BriefingRecord record) async {
    final doc = await _col.add(record.toFirestore());
    return doc.id;
  }

  static Future<void> update(BriefingRecord record) async {
    await _col.doc(record.id).update(record.toFirestore());
  }

  static Future<void> updateTitle(String id, String title) async {
    await _col.doc(id).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
