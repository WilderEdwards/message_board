// board_service.dart
// everything the board needs from firestore: create a message, stream the
// collection, update one, delete one

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _messages {
    return _db.collection('messages');
  }

  // live stream, ordered oldest to newest by the server clock
  Stream<List<Message>> getMessages() {
    return _messages.orderBy('createdAt').snapshots().map((snapshot) {
      List<Message> list = [];
      for (int i = 0; i < snapshot.docs.length; i++) {
        list.add(Message.fromDoc(snapshot.docs[i]));
      }
      return list;
    });
  }

  Future<void> createMessage(Message message) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('you have to be signed in to post');
    }

    await _messages.add(message.toCreateMap());
  }

  Future<void> updateMessage(Message message, String newText) async {
    await _messages.doc(message.id).update(message.toUpdateMap(newText));
  }

  Future<void> deleteMessage(Message message) async {
    await _messages.doc(message.id).delete();
  }
}
