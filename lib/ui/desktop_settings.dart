import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class DesktopSettingsPage extends StatefulWidget {
  const DesktopSettingsPage({super.key});

  @override
  State<DesktopSettingsPage> createState() => _DesktopSettingsPageState();
}

class _DesktopSettingsPageState extends State<DesktopSettingsPage> {
  bool _notificationsEnabled = true;
  late Box box;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    box = Hive.box('settings');
    _usernameController.text =
        box.get('displayName', defaultValue: 'AirChatUser');
        _notificationsEnabled = box.get('notifications', defaultValue: true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    await box.put('displayName', _usernameController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: colorScheme.onSurfaceVariant,
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: colorScheme.onPrimary)),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Account',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                  filled: true,
                  // fillColor: colorScheme.surface,
                  labelStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              // Theme mode section
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 15,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.brightness_6,
                              ),
                              const SizedBox(width: 10),
                              Text('Theme',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface)),
                            ],
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            groupValue: themeProvider.themeMode,
                            onChanged: (val) =>
                                themeProvider.setThemeMode(ThemeMode.light),
                            title: Text('Light',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.onSurface)),
                            activeColor: colorScheme.primary,
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            groupValue: themeProvider.themeMode,
                            onChanged: (val) =>
                                themeProvider.setThemeMode(ThemeMode.dark),
                            title: Text('Dark',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.onSurface)),
                            activeColor: colorScheme.primary,
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.system,
                            groupValue: themeProvider.themeMode,
                            onChanged: (val) =>
                                themeProvider.setThemeMode(ThemeMode.system),
                            title: Text('System',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.onSurface)),
                            activeColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SwitchListTile(
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
                },
                title: Text('Enable Notifications',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface)),
                secondary: Icon(Icons.notifications_active),
                activeColor: colorScheme.primary,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  'Save Settings',
                  style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onPrimary),
                ),
                onPressed: _saveSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
