// lib/widgets/dialogs/messages_dialog.dart
import 'dart:html' hide VoidCallback;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesDialog extends StatefulWidget {
  final Function(String, String, String)? onChatSelected;
  
  const MessagesDialog({Key? key, this.onChatSelected}) : super(key: key);

  @override
  _MessagesDialogState createState() => _MessagesDialogState();
}

class _MessagesDialogState extends State<MessagesDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> chats = [];
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  Future<void> _loadChats() async {
    // Implementation would go here
    // For now, just set loading to false
    setState(() {
      isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  "Messages",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Message list or loading indicator
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.message, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Click on a user's profile to start chatting",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return ListTile(
                            title: Text(chat['displayName'] ?? 'User'),
                            subtitle: Text(chat['lastMessage'] ?? ''),
                            onTap: () {
                              if (widget.onChatSelected != null) {
                                widget.onChatSelected!(
                                  chat['userId'],
                                  chat['displayName'],
                                  chat['photoURL'],
                                );
                              }
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