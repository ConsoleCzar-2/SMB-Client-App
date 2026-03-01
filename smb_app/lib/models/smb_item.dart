// data model for file/folder

// Class for file/folder representation
class SmbItem {
  final String name;		// final === const
  final bool isDirectory;

  // constructor
  const SmbItem({required this.name, required this.isDirectory});	// required : value is must
}

/* Sample Usage
List<SmbItem> items = [
  SmbItem(name: "Movies", isDirectory: true),
  SmbItem(name: "song.mp3", isDirectory: false),
]; 

for (var item in items) {
  if (item.isDirectory) {
    print("Folder:  ${item.name}");
  } else {
    print("File: ${item.name}");
  }
}
*/