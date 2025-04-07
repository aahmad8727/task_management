import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SortOption { priority, dueDate, completion }

enum FilterOption { all, high, medium, low, completed, incomplete }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase CRUD App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  // Controllers for user input
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  // Priority selection
  String _selectedPriority = 'Medium';

  // Sorting & Filtering
  SortOption _selectedSort = SortOption.priority;
  FilterOption _selectedFilter = FilterOption.all;

  // Firestore reference
  final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('tasks');

  // Current user (for Firebase Auth)
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

    // If user is logged in, show tasks screen
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Tasks'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _selectedSort = value),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: SortOption.priority,
                    child: Text('Sort by Priority'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.dueDate,
                    child: Text('Sort by Due Date'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.completion,
                    child: Text('Sort by Completion'),
                  ),
                ],
          ),

          PopupMenuButton<FilterOption>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: FilterOption.all,
                    child: Text('All Tasks'),
                  ),
                  const PopupMenuItem(
                    value: FilterOption.high,
                    child: Text('High Priority'),
                  ),
                  const PopupMenuItem(
                    value: FilterOption.medium,
                    child: Text('Medium Priority'),
                  ),
                  const PopupMenuItem(
                    value: FilterOption.low,
                    child: Text('Low Priority'),
                  ),
                  const PopupMenuItem(
                    value: FilterOption.completed,
                    child: Text('Completed Tasks'),
                  ),
                  const PopupMenuItem(
                    value: FilterOption.incomplete,
                    child: Text('Incomplete Tasks'),
                  ),
                ],
          ),

          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Task Name
                TextField(
                  controller: _taskNameController,
                  decoration: const InputDecoration(labelText: 'Task Name'),
                ),
                const SizedBox(height: 8),
                // Priority Dropdown
                Row(
                  children: [
                    const Text('Priority:'),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedPriority,
                      items: const [
                        DropdownMenuItem(value: 'High', child: Text('High')),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value ?? 'Medium';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Due Date
                TextField(
                  controller: _dueDateController,
                  decoration: const InputDecoration(
                    labelText: 'Due Date (optional, e.g. 2025-04-07)',
                  ),
                ),
                const SizedBox(height: 10),
                // Add Task Button
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Add Task'),
                ),
              ],
            ),
          ),

          // ---------- Task List (StreamBuilder) ----------
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

                // Convert to a mutable list
                List<QueryDocumentSnapshot> tasks =
                    snapshot.data!.docs.toList();

                // Filter tasks
                tasks = _filterTasks(tasks);

                // Sort tasks
                tasks = _sortTasks(tasks);

                // Build list view
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final doc = tasks[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String name = data['name'] ?? '';
                    final bool isCompleted = data['isCompleted'] ?? false;
                    final String priority = data['priority'] ?? 'Medium';
                    final String dueDate = data['dueDate'] ?? '';

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
                      subtitle: Text(
                        'Priority: $priority'
                        '${dueDate.isNotEmpty ? " | Due: $dueDate" : ""}',
                        style: TextStyle(color: _getPriorityColor(priority)),
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

  // ---------- Authentication Methods ----------
  Future<void> _signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  //crud
  Future<void> _addTask() async {
    final name = _taskNameController.text.trim();
    final dueDate = _dueDateController.text.trim();

    if (name.isNotEmpty && _currentUser != null) {
      await _tasksCollection.add({
        'name': name,
        'isCompleted': false,
        'priority': _selectedPriority,
        'dueDate': dueDate,
        'userId': _currentUser!.uid,
      });
      // Clear fields
      _taskNameController.clear();
      _dueDateController.clear();
      setState(() {
        _selectedPriority = 'Medium';
      });
    }
  }

  Future<void> _toggleTaskCompletion(String docId, bool isCompleted) async {
    await _tasksCollection.doc(docId).update({'isCompleted': isCompleted});
  }

  Future<void> _deleteTask(String docId) async {
    await _tasksCollection.doc(docId).delete();
  }

  List<QueryDocumentSnapshot> _filterTasks(List<QueryDocumentSnapshot> tasks) {
    switch (_selectedFilter) {
      case FilterOption.high:
        return tasks.where((doc) => doc['priority'] == 'High').toList();
      case FilterOption.medium:
        return tasks.where((doc) => doc['priority'] == 'Medium').toList();
      case FilterOption.low:
        return tasks.where((doc) => doc['priority'] == 'Low').toList();
      case FilterOption.completed:
        return tasks.where((doc) => doc['isCompleted'] == true).toList();
      case FilterOption.incomplete:
        return tasks.where((doc) => doc['isCompleted'] == false).toList();
      case FilterOption.all:
      default:
        return tasks;
    }
  }

  List<QueryDocumentSnapshot> _sortTasks(List<QueryDocumentSnapshot> tasks) {
    switch (_selectedSort) {
      case SortOption.priority:
        // Sort High > Medium > Low
        tasks.sort((a, b) {
          final pA = a['priority'] ?? 'Medium';
          final pB = b['priority'] ?? 'Medium';
          return _priorityValue(pB).compareTo(_priorityValue(pA));
        });
        break;

      case SortOption.dueDate:
        // Sort by dueDate ascending (string comparison)
        tasks.sort((a, b) {
          final dA = a['dueDate'] ?? '';
          final dB = b['dueDate'] ?? '';
          return dA.compareTo(dB);
        });
        break;

      case SortOption.completion:
        // Incomplete first, completed last
        tasks.sort((a, b) {
          final cA = a['isCompleted'] ?? false;
          final cB = b['isCompleted'] ?? false;
          // false < true => incomplete < completed
          return cA.toString().compareTo(cB.toString());
        });
        break;
    }
    return tasks;
  }

  int _priorityValue(String priority) {
    switch (priority) {
      case 'High':
        return 3;
      case 'Medium':
        return 2;
      case 'Low':
        return 1;
      default:
        return 0;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
