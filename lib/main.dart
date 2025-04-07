import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();

  final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('tasks');

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Listen to auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // If user not logged in, show a sign-in button
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firebase Tasks')),
        body: Center(
          child: ElevatedButton(
            onPressed: _signInAnonymously,
            child: const Text('Sign In Anonymously'),
          ),
        ),
      );
    }

    // If user is logged in, show the task list
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Tasks'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: Column(
        children: [
          // Input field + Add button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: 'Enter task name',
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addTask),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _tasksCollection
                      .where('userId', isEqualTo: _currentUser!.uid)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final doc = tasks[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String name = data['name'] ?? '';
                    final bool isCompleted = data['isCompleted'] ?? false;

                    return ListTile(
                      leading: Checkbox(
                        value: isCompleted,
                        onChanged:
                            (value) =>
                                _toggleTaskCompletion(doc.id, value ?? false),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          decoration:
                              isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTask(doc.id),
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

  // Method to sign in anonymously
  Future<void> _signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
    }
  }

  // Method to sign out
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // Method to add a task
  Future<void> _addTask() async {
    final taskName = _taskController.text.trim();
    if (taskName.isNotEmpty && _currentUser != null) {
      await _tasksCollection.add({
        'name': taskName,
        'isCompleted': false,
        'userId': _currentUser!.uid,
      });
      _taskController.clear();
    }
  }

  // Method to toggle completion status
  Future<void> _toggleTaskCompletion(String docId, bool isCompleted) async {
    await _tasksCollection.doc(docId).update({'isCompleted': isCompleted});
  }

  // Method to delete a task
  Future<void> _deleteTask(String docId) async {
    await _tasksCollection.doc(docId).delete();
  }
}
