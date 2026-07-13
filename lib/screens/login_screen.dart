// UI for the login screen, where users will enter the SMB credentials

import 'package:flutter/material.dart';
import '../services/smb_service.dart';
import '../services/credential_service.dart';
import 'file_browser_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const LoginScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  // Controllers let us read field values and pre-fill them
  final _hostController     = TextEditingController();
  final _shareController    = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe      = false;
  bool _obscurePassword = true;   // toggles password visibility
  bool _isLoading       = false;  // shows spinner on the button while connecting
  String? _errorMessage;          // null = no error shown

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final remembered = await CredentialService.isRemembered();
    if (!remembered) return;

    final creds = await CredentialService.load();
    // setState needed because we're updating UI from an async call
    setState(() {
      _hostController.text     = creds['host']     ?? '';
      _shareController.text    = creds['share']    ?? '';
      _usernameController.text = creds['username'] ?? '';
      _passwordController.text = creds['password'] ?? '';
      _rememberMe = true;
    });
  }

  Future<void> _connect() async {
    // Basic validation — don't even try if fields are empty
    if (_hostController.text.isEmpty || _shareController.text.isEmpty) {
      setState(() => _errorMessage = 'Host and Share are required.');
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = null;  // clear any previous error
    });

    try {
      if (_rememberMe) {
        await CredentialService.save(
          host:     _hostController.text.trim(),
          share:    _shareController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await CredentialService.clear();  // wipe saved creds if unchecked
      }

      final service = SmbService(
        host:     _hostController.text.trim(),
        share:    _shareController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await service.init();  // actual network call — will throw on failure

      if (!mounted) return;
      // pushReplacement so back button doesn't return to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FileBrowserScreen(
            service: service,
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Connection failed: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    // Always dispose controllers to free memory
    _hostController.dispose();
    _shareController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMB Login'),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Host IP'),
              keyboardType: TextInputType.url,
            ),
            TextField(
              controller: _shareController,
              decoration: const InputDecoration(labelText: 'Shared Folder'),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                ),
                const Text('Remember me'),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _connect,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}