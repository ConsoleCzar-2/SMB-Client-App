// For the App UI and navigation

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/smb_item.dart';
import '../services/smb_service.dart';
import 'package:open_filex/open_filex.dart';

// Caller class for file browsing screen
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

// Contains UI and file browsing logic
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

  // Closing session when work is done (Descructor)
  @override
  void dispose() {
    _service.disconnect();
    super.dispose();
  }

  // Helper func for initializing session and loading folder/file data
  Future<List<SmbItem>> _initAndLoad() async {
    await _service.init();
    if (_currentPath == "/") {
      return _service.listShares();  // lists shared folders at root
    }
    else{
      return _service.listDirectory(_currentPath);  // lists all files/folders at current path 
    }
  }

  // Hepler func for getting the parent path, useful for naviating up
  String getParentPath(String path) {
  final parts = path.split('/')..removeWhere((e) => e.isEmpty);

  if (parts.isNotEmpty) {
    parts.removeLast();
  }

  return parts.isEmpty ? "/" : "/${parts.join('/')}/";
  }

  // Navigation func
  void _loadPath(String path) {
    // Tells app to update the UI
    setState(() {
      _currentPath = path;
      if (path == "/") {
        _items = _service.listShares();
      } else {
        _items = _service.listDirectory(path);
      }
    });
  }

  // Helps in building the new path
  String buildPath(String base, String name) {
    if (base == "/") {
      return "/$name/";
    } 
    else {
      return "$base$name/";
    }
  }

  // Opens the file which is clicked
  // It first downloads the file at a temp location allocated by the OS and opens it from there
  Future<void> _openFile(String path, String fname) async {
    // Loading screen as file's being downloaded
    showDialog(
      context: context, // where to show logo
      barrierDismissible: false,  // prevents user from closing dialog by clicking outside
      builder: (builderContext) => const AlertDialog( // Opens the dialog box
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Downloading..."), // TODO: add progress %age
          ],
        ),
      ),
    );

    try {
      final localPath = await _service.downloadFile(path, fname);
      if (mounted) {
        Navigator.of(context).pop(); // to close dialog after download finished
      }
      // TODO: use variuos methods to open different file types
      await OpenFilex.open(localPath);  // opens downloaded file
    }
    catch (e) {
      if (mounted) {
        Navigator.of(context).pop();  // closes dialog when error
        // Snackbar is the popup notification at bottom of the screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
          ),
        );
      }
      else {
        // Widget not mounted, so we can just print error msg
        debugPrint("Error: ${e.toString()}");
      }
    }
  }


  // Main UI Function
  // Given the current state(context), it returns the corresponding UI (widget) === Rendering UI with new 
  @override
  Widget build(BuildContext context) {

    // PopScope has been used to handle the back button press
    return PopScope(
      canPop: _currentPath == "/",  // allow exit only when truly at root (optional: always block)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPath != "/") {
          // navigate up instead
          _loadPath(getParentPath(_currentPath));
        }
      },
      child: Scaffold(    // Contains basic structure of AppBar(like Navbar) and Body
        appBar: AppBar(
          title: Text(_currentPath),  // first shown is current folder
          leading: _currentPath != "/" ? IconButton(    // Shows back button only if not root folder
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _loadPath(getParentPath(_currentPath));
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
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}'),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _items = _initAndLoad();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // --- State 3: data correctly loaded ---
            final items = snapshot.data!; // '!' for non-nulll asssertion, i.e. the variable can't be null at runtime

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
                          final newPath = buildPath(_currentPath, item.name);
                          _loadPath(newPath);
                        }
                      : () { /* TODO: download files specifying download path */ 

                          final filePath = buildPath(_currentPath, item.name).replaceAll(RegExp(r"/$"), "");  // removes trailing "/" for files
                          _openFile(filePath, item.name);
                      },
                );
              },
            );
          },
        ),
      ),
    );
  }
}