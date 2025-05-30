import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavemark_app_v1/etc/app_settings.dart'; // Adjust path if needed
import 'package:wavemark_app_v1/etc/pingServer.dart'; // Adjust path if needed

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _serverIp;
  final TextEditingController _serverIpController = TextEditingController();
  String _serverIpFeedbackMessage = '';
  bool _isLoadingSettings = true;
  bool _isPinging = false;

  static const Color _scaffoldBgColor = Color(0xFFF5E8E4);
  static const Color _appBarFgColor = Color(0xFF411530);
  static const Color _headingTextColor = Color(0xFF411530);
  static const Color _bodyTextColor = Color(0xFF4F4A45);
  static const Color _accentColor = Color(0xFFD1512D);
  static const Color _whiteColor = Colors.white;
  static const Color _secondaryButtonBgColor = Color(0xFFE0E0E0);
  static const Color _textFieldBorderColor = Colors.grey;
  static const Color _textFieldFocusedBorderColor = _accentColor;
  static const Color _textFieldLabelColor = Color(0xFF616161);
  static const Color _infoBoxBorderColor =
      Color(0xFFD3CFCF); // A color for info box border
  static const Color _infoBoxIconColor =
      Color(0xFF411530); // Color for the info icon

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    setState(() {
      _isLoadingSettings = true;
    });
    await _loadSavedServerIp();
    setState(() {
      _isLoadingSettings = false;
    });
  }

  Future<void> _loadSavedServerIp() async {
    final String loadedIp = await AppSettings.getServerIp();
    if (mounted) {
      setState(() {
        _serverIp = loadedIp;
        _serverIpController.text = loadedIp;
      });
    }
  }

  Future<void> _saveServerIp() async {
    if (_serverIpController.text.isEmpty) {
      if (mounted)
        setState(
            () => _serverIpFeedbackMessage = 'IP address cannot be empty.');
      return;
    }
    final RegExp ipRegex = RegExp(
        r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");
    if (!ipRegex.hasMatch(_serverIpController.text)) {
      if (mounted)
        setState(() => _serverIpFeedbackMessage =
            'Invalid IP address format (e.g., 192.168.1.100).');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSettings.serverIpKey, _serverIpController.text);
    if (mounted) {
      setState(() {
        _serverIp = _serverIpController.text;
        _serverIpFeedbackMessage = 'Server IP saved successfully!';
      });
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _serverIpFeedbackMessage = '';
        });
      }
    });
  }

  Future<void> _resetServerIpToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppSettings.serverIpKey);
    if (mounted) {
      setState(() {
        _serverIp = AppSettings.defaultServerIp;
        _serverIpController.text = AppSettings.defaultServerIp;
        _serverIpFeedbackMessage =
            'Server IP reset to default (${AppSettings.defaultServerIp}).';
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _serverIpFeedbackMessage = '';
        });
      }
    });
  }

  Future<void> _handlePingServer() async {
    if (_isPinging) return;

    if (mounted) setState(() => _isPinging = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool isAlive = await ServerPinger.ping();

    if (mounted) {
      setState(() => _isPinging = false);
      if (isAlive) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text("Server is reachable! ✅"),
              backgroundColor: Colors.green),
        );
      } else {
        final String currentIpForPing = await AppSettings.getServerIp();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                "Server not reachable at $currentIpForPing (or not responding). ❌"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: _headingTextColor,
        fontSize: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: const Text("Settings",
            style:
                TextStyle(color: _appBarFgColor, fontFamily: 'Archivo Black')),
        backgroundColor: _scaffoldBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _appBarFgColor),
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Server IP Address"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _whiteColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _textFieldBorderColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Text('Current: ',
                            style:
                                TextStyle(color: _bodyTextColor, fontSize: 16)),
                        Expanded(
                          child: Text(
                            _serverIp ?? AppSettings.defaultServerIp,
                            style: const TextStyle(
                                color: _headingTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverIpController,
                    decoration: InputDecoration(
                      labelText: 'Enter Server IP',
                      labelStyle: const TextStyle(color: _textFieldLabelColor),
                      hintText: 'e.g., ${AppSettings.defaultServerIp}',
                      hintStyle: TextStyle(
                          color: _textFieldLabelColor.withOpacity(0.7)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _textFieldBorderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _textFieldBorderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _textFieldFocusedBorderColor, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: _bodyTextColor),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveServerIp,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Save IP"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: _whiteColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetServerIpToDefault,
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text("Reset IP"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _secondaryButtonBgColor,
                            foregroundColor: _headingTextColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_serverIpFeedbackMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _serverIpFeedbackMessage,
                      style: TextStyle(
                        color:
                            _serverIpFeedbackMessage.contains('successfully') ||
                                    _serverIpFeedbackMessage
                                        .contains('reset to default')
                                ? Colors.green.shade700
                                : _accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isPinging ? null : _handlePingServer,
                      icon: _isPinging
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: _whiteColor,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.network_ping_sharp), // Updated Icon
                      label: const Text("Ping Server"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF393646),
                        foregroundColor: _whiteColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 24), // Spacing before the new contact box

                  // --- New Contact Information Box ---
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: _appBarFgColor
                          .withOpacity(0.05), // Light background tint
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: _infoBoxBorderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.contact_support_outlined,
                          color: _infoBoxIconColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Need Help with Server IP?",
                                style: TextStyle(
                                  color: _headingTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "If you're having trouble connecting to the server or need the correct IP address, please contact:\nTechnical Team at 0812-1176-5751.",
                                style: TextStyle(
                                  color: _bodyTextColor,
                                  fontSize: 14,
                                ),
                              ),
                              // Example of how to make an email clickable (optional)
                              // const SizedBox(height: 8),
                              // InkWell(
                              //   onTap: () {
                              //     // You would use url_launcher here to open the email app
                              //     // launchUrlString('mailto:support@example.com');
                              //   },
                              //   child: Text(
                              //     "support@example.com",
                              //     style: TextStyle(
                              //       color: _accentColor,
                              //       decoration: TextDecoration.underline,
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
