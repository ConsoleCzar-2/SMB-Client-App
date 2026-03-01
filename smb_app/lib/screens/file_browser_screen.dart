import 'package:flutter/material.dart';
import '../models/smb_item.dart';
import '../services/smb_service.dart';
// For the App UI and navigation

// Screen class for browsing the files
// Uses Stateful as the file list will update with each click
class FileBrowserScreen extends StatefulWidget {
  final SmbService service;
  const FileBrowserScreen({   // Constructor (taking key from parent widget)
    super.key,
    required this.service,
    }
  );

  // *** IMP : Variables starting with an '_' in flutter, means that it is private to the file, just like in CPP. 
  // override is for Function Overriding
  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {

  late final SmbService _service;

  String _currentPath = "/"; // to keep track of current position (Defauld root)
  late Future<List<SmbItem>> _items; // Var for holding the items once NW call is finished

  // Initializing session
  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _items = _initAndLoad();
  }

  Future<List<SmbItem>> _initAndLoad() async {
    await _service.init();
    if (_currentPath == "/") {
      return _service.listShared();  // lists shared folders at root
    }
    else{
      return _service.listDirectory(_currentPath);  // lists all files/folders at current path 
    }
  }


  // Navigation func
  void _loadPath(String path) {
    // Tells app to update the UI
    setState(() {
      _currentPath = path;
      _items = _service.listDirectory(path);
    });
  }

  // Given the current state(context), it returns the corresponding UI (widget) === Rendering UI with new 
  @override
  Widget build(BuildContext context) {
    return Scaffold(    // Contains basic structure of AppBar(like Navbar) and Body
      appBar: AppBar(
        title: Text(_currentPath),  // first shown is current folder
        leading: _currentPath != "/" ? IconButton(    // Shows back button only if not root folder
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final parent = _currentPath.substring(0, _currentPath.lastIndexOf("/", _currentPath.length - 2) + 1);  // to remove last folder on clicking back button, i.e. goes 1 folder above
            _loadPath(parent.isEmpty ? "/" : parent); // returns to root if parent is empty
          },
        )
        : null,
      ),

      // Handles the UI for the main data
      body: FutureBuilder<List<SmbItem>>(
        future: _items,
        builder: (context, snapshot) {

          // 3 types of states are possible
          // State 1: still loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // State 2: an error occurred
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // --- State 3: data arrived ---
          final items = snapshot.data!; // '!' for non-nulll asssertion, i.e. a null vatiable is converted to it's equivalent non-null

          if (items.isEmpty) {
            return const Center(child: Text('Empty folder'));
          }

          // ListView.builder is the "loop" — index goes 0..items.length-1
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(
                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  color: item.isDirectory ? Colors.amber : Colors.blueGrey,
                ),
                title: Text(item.name),
                onTap: item.isDirectory
                    ? () {
                        final newPath = _currentPath == "/"
                            ? "/${item.name}/"
                            : "$_currentPath${item.name}/";
                        _loadPath(newPath);
                      }
                    : () { /* open file — Phase 4 */ },
              );
            },
          );
        },
      ),
    );
  }
}