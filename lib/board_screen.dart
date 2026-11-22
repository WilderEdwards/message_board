// board_screen.dart
// the message board: post box on top, live list under it, edit and delete
// only on your own messages

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'board_service.dart';
import 'models.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService _board = BoardService();
  final AuthService _auth = AuthService();
  final _textController = TextEditingController();

  bool _posting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // the auth emulator hands back an empty display name, so fall back to email
  String _nameOf(User? user) {
    if (user == null) {
      return '';
    }
    String name = (user.displayName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return (user.email ?? '').trim();
  }

  Future<void> _post() async {
    if (_posting) {
      return;
    }
    String text = _textController.text.trim();
    if (text.isEmpty) {
      _showMessage('Type something first');
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      _showMessage('You are signed out');
      return;
    }

    setState(() {
      _posting = true;
    });

    try {
      String author = _nameOf(user);
      Message message = Message(
        text: text,
        authorUid: user.uid,
        authorName: author.isEmpty ? 'unknown' : author,
      );
      await _board.createMessage(message);
      _textController.clear();
    } catch (e) {
      _showMessage('Could not post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  Future<void> _edit(Message message) async {
    // the dialog writes into this, no controller to dispose while it closes
    String draft = message.text;

    String? newText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextFormField(
            initialValue: message.text,
            autofocus: true,
            maxLines: 3,
            onChanged: (value) {
              draft = value;
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, draft);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newText == null || newText.trim().isEmpty) {
      return;
    }
    if (newText.trim() == message.text) {
      return;
    }

    try {
      await _board.updateMessage(message, newText);
    } catch (e) {
      _showMessage('Could not update: $e');
    }
  }

  Future<void> _delete(Message message) async {
    bool? sure = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (sure != true) {
      return;
    }

    try {
      await _board.deleteMessage(message);
    } catch (e) {
      _showMessage('Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        backgroundColor: Colors.deepOrange.shade50,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                _nameOf(user),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // the post box
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _posting ? null : _post,
                    child: _posting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),

          // the live board
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _board.getMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load the board: ${snapshot.error}'),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Message> messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No messages yet.\nBe the first to post.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    Message message = messages[index];
                    bool mine = user != null && message.ownerUid == user.uid;
                    String initial =
                        message.authorName.isEmpty
                            ? '?'
                            : message.authorName.substring(0, 1).toUpperCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.deepOrange.shade100,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // edit and delete only on my own messages
                                if (mine) ...[
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      _edit(message);
                                    },
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete, size: 18),
                                    onPressed: () {
                                      _delete(message);
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.text,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.createdAt == null
                                  ? 'sending...'
                                  : message.createdAt.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            if (message.editedAt != null)
                              const Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
