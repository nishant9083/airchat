import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _controller = TextEditingController();
  late Box box;
  bool _autoAccept = false;
  bool _autoConnect = false;
  bool _autoAdvertise = false;
  bool _autoDiscover = false;

  @override
  void initState() {
    super.initState();
    box = Hive.box('settings');
    _controller.text = box.get('displayName', defaultValue: 'AirChatUser');
    _autoAccept = box.get('autoAccept', defaultValue: false);
    _autoConnect = box.get('autoConnect', defaultValue: false);
    _autoAdvertise = box.get('autoAdvertise', defaultValue: false);
    _autoDiscover = box.get('autoDiscover', defaultValue: false);
  }

  void _save() async {
    await box.put('displayName', _controller.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name saved!')));
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    await box.put(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_labelForKey(key)}: ${value ? 'Enabled' : 'Disabled'}')),
      );
    }
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'autoAccept':
        return 'Auto Accept';
      case 'autoConnect':
        return 'Auto Connect';
      case 'autoAdvertise':
        return 'Auto Advertise';
      case 'autoDiscover':
        return 'Auto Discover';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.primary,
                          child: Icon(Icons.person, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Profile', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Set your display name for AirChat', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        border: const UnderlineInputBorder(),
                        // filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                        hintText: 'Enter your display name',
                        prefixIcon: const Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(120, 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection Preferences', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Control how AirChat connects and discovers devices.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Auto Accept Connections'),
                      subtitle: const Text('Automatically accept incoming connection requests.'),
                      value: _autoAccept,
                      onChanged: (val) {
                        setState(() => _autoAccept = val);
                        _saveToggle('autoAccept', val);
                      },
                      secondary: Icon(Icons.check_circle_outline, color: _autoAccept ? colorScheme.secondary : Colors.grey),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Auto Connect to Devices'),
                      subtitle: const Text('Automatically connect to discovered devices.'),
                      value: _autoConnect,
                      onChanged: (val) {
                        setState(() => _autoConnect = val);
                        _saveToggle('autoConnect', val);
                      },
                      secondary: Icon(Icons.link, color: _autoConnect ? colorScheme.secondary : Colors.grey),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Auto Advertise'),
                      subtitle: const Text('Automatically make your device visible to others.'),
                      value: _autoAdvertise,
                      onChanged: (val) {
                        setState(() => _autoAdvertise = val);
                        _saveToggle('autoAdvertise', val);
                      },
                      secondary: Icon(Icons.campaign, color: _autoAdvertise ? colorScheme.secondary : Colors.grey),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Auto Discover'),
                      subtitle: const Text('Automatically search for nearby devices.'),
                      value: _autoDiscover,
                      onChanged: (val) {
                        setState(() => _autoDiscover = val);
                        _saveToggle('autoDiscover', val);
                      },
                      secondary: Icon(Icons.search, color: _autoDiscover ? colorScheme.secondary : Colors.grey),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 