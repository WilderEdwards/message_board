// models.dart
// the two documents the app stores, and the property they share

import 'package:cloud_firestore/cloud_firestore.dart';

// every document belongs to one uid, that is what the rules check
mixin Owned {
  String get ownerUid;
}

// users/{uid}
class UserRecord with Owned {
  final String uid;
  final String firstName;
  final String lastName;
  final String role;

  UserRecord({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  @override
  String get ownerUid {
    return uid;
  }

  // the five fields the assignment asks for
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    };
  }
}

// messages/{msgId}
class Message with Owned {
  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final int schemaVersion;

  Message({
    this.id = '',
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
    this.schemaVersion = 1,
  });

  @override
  String get ownerUid {
    return authorUid;
  }

  // read one document back into a message
  factory Message.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Timestamp? created = data['createdAt'] as Timestamp?;
    Timestamp? edited = data['editedAt'] as Timestamp?;

    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      authorUid: data['authorUid'] ?? '',
      authorName: data['authorName'] ?? 'unknown',
      createdAt: created?.toDate(),
      editedAt: edited?.toDate(),
      schemaVersion: data['schemaVersion'] ?? 1,
    );
  }

  // what a new message writes
  Map<String, dynamic> toCreateMap() {
    return {
      'text': text,
      'authorUid': authorUid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'schemaVersion': schemaVersion,
    };
  }

  // only the text moves, the owner fields stay put
  Map<String, dynamic> toUpdateMap(String newText) {
    return {
      'text': newText.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    };
  }
}
