import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Display name saved!'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    await box.put(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.toggle_on : Icons.toggle_off,
                color: value ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text('${_labelForKey(key)}: ${value ? 'Enabled' : 'Disabled'}'),
            ],
          ),
          backgroundColor: value ? Colors.green[700] : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
        ),
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

  Widget _buildProfileCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha:0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: colorScheme.primary.withValues(alpha:0.18),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: colorScheme.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 38),
                ),
              ),
              // Positioned(
              //   bottom: 0,
              //   right: 0,
              //   child: Material(
              //     color: colorScheme.secondary,
              //     shape: const CircleBorder(),
              //     child: Padding(
              //       padding: const EdgeInsets.all(4.0),
              //       child: Icon(Icons.edit, color: Colors.white, size: 18),
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your Profile',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set your display name for AirChat',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: .6),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surface.withValues(alpha: .7),
              hintText: 'Enter your display name',
              prefixIcon:  Icon(Icons.person_outline, color: theme.brightness==Brightness.dark?colorScheme.secondaryContainer:colorScheme.primary,),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPrefsCard(ThemeData theme, ColorScheme colorScheme) {
    final prefs = [
      {
        'title': 'Auto Accept Connections',
        'subtitle': 'Automatically accept incoming connection requests.',
        'value': _autoAccept,
        'icon': Icons.check_circle_outline,
        'key': 'autoAccept',
        'onChanged': (bool val) {
          setState(() => _autoAccept = val);
          _saveToggle('autoAccept', val);
        },
      },
      {
        'title': 'Auto Connect to Devices',
        'subtitle': 'Automatically connect to discovered devices.',
        'value': _autoConnect,
        'icon': Icons.link,
        'key': 'autoConnect',
        'onChanged': (bool val) {
          setState(() => _autoConnect = val);
          _saveToggle('autoConnect', val);
        },
      },
      {
        'title': 'Auto Advertise',
        'subtitle': 'Automatically make your device visible to others.',
        'value': _autoAdvertise,
        'icon': Icons.campaign,
        'key': 'autoAdvertise',
        'onChanged': (bool val) {
          setState(() => _autoAdvertise = val);
          _saveToggle('autoAdvertise', val);
        },
      },
      {
        'title': 'Auto Discover',
        'subtitle': 'Automatically search for nearby devices.',
        'value': _autoDiscover,
        'icon': Icons.search,
        'key': 'autoDiscover',
        'onChanged': (bool val) {
          setState(() => _autoDiscover = val);
          _saveToggle('autoDiscover', val);
        },
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_antenna, color: colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Connection Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Control how AirChat connects and discovers devices.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: .6),
            ),
          ),
          const SizedBox(height: 18),
          ...prefs.map((pref) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      pref['icon'] as IconData,
                      color: (pref['value'] as bool)
                          ? colorScheme.secondary
                          : colorScheme.onSurface.withValues(alpha: .4),
                    ),
                    title: Text(
                      pref['title'] as String,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      pref['subtitle'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: .6),
                      ),
                    ),
                    trailing: Switch(
                      value: pref['value'] as bool,
                      onChanged: pref['onChanged'] as void Function(bool),
                      activeColor: colorScheme.secondary,
                      inactiveTrackColor: colorScheme.onSurface.withValues(alpha: .4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(),),
        elevation: 0,
        // backgroundColor: colorScheme.surface,
        // foregroundColor: colorScheme.onSurface,
        centerTitle: true,
      ),
      body: Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: .5),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          children: [
            _buildProfileCard(theme, colorScheme),
            const SizedBox(height: 32),
            // _buildConnectionPrefsCard(theme, colorScheme),
            // const SizedBox(height: 32),
            // Theme toggle section
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.brightness_6,  size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Theme',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                // color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose your preferred theme mode.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: .6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          groupValue: themeProvider.themeMode,
                          onChanged: (val) => themeProvider.setThemeMode(ThemeMode.light),
                          title: const Text('Light'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          groupValue: themeProvider.themeMode,
                          onChanged: (val) => themeProvider.setThemeMode(ThemeMode.dark),
                          title: const Text('Dark'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          groupValue: themeProvider.themeMode,
                          onChanged: (val) => themeProvider.setThemeMode(ThemeMode.system),
                          title: const Text('System'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Add more settings sections here if needed
            Center(
              child: Text(
                'AirChat v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: .5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}