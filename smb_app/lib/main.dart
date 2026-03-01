import 'package:flutter/material.dart';
import 'package:smb_app/services/smb_service.dart';
import 'package:smb_app/screens/file_browser_screen.dart';

void main() {
  // TODO: Contains hardcoded SMB connection details for now, would be user input later on
  final smbService = SmbService(
    host: "192.168.29.149", 
    share: "cst_iiests", 
    username: "smbuser", 
    password: "2023",
  );

  runApp(MyApp(service: smbService));
}

class MyApp extends StatelessWidget {
  final SmbService service;

  const MyApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SMB Client App",
      home: FileBrowserScreen(service: service),
    );
  }
}