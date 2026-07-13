// For the App UI and navigation

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/smb_item.dart';
import '../services/credential_service.dart';
import '../services/smb_service.dart';
import 'package:open_filex/open_filex.dart';
import 'login_screen.dart';

// Caller class for file browsing screen
// Uses Stateful as the file list will update with each click
class FileBrowserScreen extends StatefulWidget {
  final SmbService service;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const FileBrowserScreen({   // Constructor (taking key from parent widget)
    super.key,
    required this.service,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

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

  bool _selectionMode = false;
  final Map<String, SmbItem> _selectedItems = {};

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
    if (_currentPath == "/") {
      return _service.listShares();  // lists shared folders at root
    }
    else{
      return _service.listDirectory(_currentPath);  // lists all files/folders at current path 
    }
  }

  Future<void> _logout() async {
    await CredentialService.clear();
    await _service.disconnect();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
      (route) => false,
    );
  }

  void _enterSelectionMode([String? path, SmbItem? item]) {
    setState(() {
      _selectionMode = true;
      if (path != null && item != null) {
        _selectedItems[path] = item;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedItems.clear();
    });
  }

  void _toggleSelection(String path, SmbItem item) {
    setState(() {
      _selectionMode = true;
      if (_selectedItems.containsKey(path)) {
        _selectedItems.remove(path);
      } else {
        _selectedItems[path] = item;
      }
    });
  }

  Future<void> _showBusyDialog(String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _dismissBusyDialog() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
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
      _selectionMode = false;
      _selectedItems.clear();
      if (path == "/") {
        _items = _service.listShares();
      } else {
        _items = _service.listDirectory(path);
      }
    });
  }

  // Helps in building the new path
  String buildFolderPath(String base, String name) {
    if (base == "/") {
      return "/$name/";
    } 
    else {
      return "$base$name/";
    }
  }

  String buildFilePath(String base, String name) {
    return buildFolderPath(base, name).replaceAll(RegExp(r"/$"), "");
  }

  String _selectionPathForItem(SmbItem item) {
    return item.isDirectory
        ? buildFolderPath(_currentPath, item.name)
        : buildFilePath(_currentPath, item.name);
  }

  // Opens the file which is clicked
  // It first downloads the file at a temp location allocated by the OS and opens it from there
  Future<void> _openFile(String path, String fname) async {
    // Loading screen as file's being downloaded
    await _showBusyDialog("Downloading...");

    try {
      final localPath = await _service.downloadFile(path, fname);
      _dismissBusyDialog();
      await OpenFilex.open(localPath);  // opens downloaded file
    }
    catch (e) {
      _dismissBusyDialog();
      if (mounted) {
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

  Future<void> _addToArchive(
    Archive archive,
    String remotePath,
    SmbItem item,
    String zipPath,
  ) async {
    if (item.isDirectory) {
      final children = await _service.listDirectory(remotePath);
      for (final child in children) {
        final childRemotePath = child.isDirectory
            ? buildFolderPath(remotePath, child.name)
            : buildFilePath(remotePath, child.name);
        await _addToArchive(
          archive,
          childRemotePath,
          child,
          '$zipPath/${child.name}',
        );
      }
      return;
    }

    final localPath = await _service.downloadFile(remotePath, item.name);
    try {
      final bytes = await File(localPath).readAsBytes();
      archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
    } finally {
      final downloadedFile = File(localPath);
      if (await downloadedFile.exists()) {
        await downloadedFile.delete();
      }
    }
  }

  Future<void> _zipSelectedItems() async {
    if (_selectedItems.isEmpty) {
      return;
    }

    await _showBusyDialog('Creating zip...');

    try {
      final archive = Archive();
      for (final entry in _selectedItems.entries) {
        await _addToArchive(
          archive,
          entry.key,
          entry.value,
          entry.value.name,
        );
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Could not create zip file');
      }

      final tempDir = await getTemporaryDirectory();
      final zipFile = File(
        '${tempDir.path}/smb_selection_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await zipFile.writeAsBytes(zipBytes, flush: true);

      _dismissBusyDialog();
      _exitSelectionMode();
      await OpenFilex.open(zipFile.path);
    } catch (e) {
      _dismissBusyDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zip failed: ${e.toString()}')),
        );
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Host: ${widget.service.host}'),
                    Text('Share: ${widget.service.share}'),
                    Text('User: ${widget.service.username}'),
                  ],
                ),
              ),
              SwitchListTile(
                secondary: Icon(
                  widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Dark mode'),
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: Text(_currentPath),  // first shown is current folder
          leading: _currentPath != "/"
              ? IconButton(    // Shows back button only if not root folder
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _loadPath(getParentPath(_currentPath));
                  },
                )
              : null,
          actions: [
            IconButton(
              tooltip: widget.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
              onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            ),
            if (_selectionMode && _selectedItems.isNotEmpty)
              IconButton(
                tooltip: 'Download as zip',
                onPressed: _zipSelectedItems,
                icon: const Icon(Icons.archive),
              ),
            if (_selectionMode)
              IconButton(
                tooltip: 'Cancel selection',
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close),
              )
            else
              IconButton(
                tooltip: 'Select multiple items',
                onPressed: () => _enterSelectionMode(),
                icon: const Icon(Icons.checklist),
              ),
          ],
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
                final itemPath = _selectionPathForItem(item);
                final isSelected = _selectedItems.containsKey(itemPath);
                return ListTile(
                  leading: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(itemPath, item),
                        )
                      : Icon(
                          item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                          color: item.isDirectory ? Colors.amber : Colors.blueGrey,
                        ),
                  title: Text(item.name),
                  trailing: _selectionMode && isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onLongPress: () => _toggleSelection(itemPath, item),
                  onTap: _selectionMode
                      ? () => _toggleSelection(itemPath, item)
                      : item.isDirectory
                          ? () {
                              final newPath = buildFolderPath(_currentPath, item.name);
                              _loadPath(newPath);
                            }
                          : () {
                              final filePath = buildFilePath(_currentPath, item.name);
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