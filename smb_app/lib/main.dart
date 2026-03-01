import 'package:flutter/material.dart';
import 'package:smb_app/services/smb_service.dart';
import 'package:smb_app/screens/file_browser_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // TODO: Contains hardcoded SMB connection details for now, would be user input later on
  WidgetsFlutterBinding.ensureInitialized(); // Required before any async
  await dotenv.load();
  
  final smbService = SmbService(
    host: dotenv.env['HOST_IP']!, 
    share: dotenv.env['SHARED_FOLDER']!, 
    username: dotenv.env['SMB_USER']!, 
    password: dotenv.env['SMB_PASS']!,
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