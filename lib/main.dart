import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';

void main() {
  runApp(const XaillaApp());
}

class XaillaApp extends StatefulWidget {
  const XaillaApp({super.key});

  @override
  State<XaillaApp> createState() => _XaillaAppState();
}

class _XaillaAppState extends State<XaillaApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xailla Class',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple), useMaterial3: true),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark), useMaterial3: true),
      home: HomeScreen(onThemeChanged: _changeTheme),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  String currentConfig = "- name: aduuhh\n  server: api24-normal.tiktokv.com\n  port: 443\n  type: trojan\n  password: efb70fbb-03b4-42a0-9033-fde234f6a69b\n  skip-cert-verify: true\n  sni: api24-normal.tiktokv.com.id2.aryus09.com\n  network: ws\n  ws-opts:\n    path: /trojan\n    headers:\n      Host: api24-normal.tiktokv.com.id2.aryus09.com\n  udp: true";

  void toggleConnection() {
    setState(() => isConnected = !isConnected);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isConnected ? 'Menghubungkan...' : 'Terputus')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('🍟 ', style: TextStyle(fontSize: 24)), Text('XAILLA-CLASS', style: TextStyle(fontWeight: FontWeight.bold))]),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: toggleConnection,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: isConnected ? Colors.green.shade700 : Colors.grey.shade600, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(isConnected ? Icons.play_arrow : Icons.block, size: 50, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(isConnected ? 'Connected' : 'Stopped', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(isConnected ? 'Tap to disconnect' : 'Tap to start', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.edit_document, color: Colors.purple),
                title: const Text('Edit Config', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Edit your config here'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConfigEditorScreen(initialConfig: currentConfig, onSave: (newConfig) => setState(() => currentConfig = newConfig)))),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.purple),
                title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(onThemeChanged: widget.onThemeChanged))),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.info, color: Colors.purple),
                title: const Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(context: context, applicationName: "Xailla Class", applicationVersion: "1.0.0"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfigEditorScreen extends StatefulWidget {
  final String initialConfig;
  final Function(String) onSave;
  const ConfigEditorScreen({super.key, required this.initialConfig, required this.onSave});

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Config Editor'), actions: [
        IconButton(icon: const Icon(Icons.save), onPressed: () {
          widget.onSave(_controller.text);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Config disimpan!')));
        })
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller, maxLines: null, expands: true,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'Paste config Vmess/Trojan/SS di sini...', fillColor: Theme.of(context).colorScheme.surfaceVariant, filled: true),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String accessMode = 'Allow all apps';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Interface', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.dark_mode), title: const Text('Dark Mode'), subtitle: const Text('Follow System (Android 10+)'),
            onTap: () => showDialog(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Pilih Tema'),
                children: [
                  SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.system); Navigator.pop(context); }, child: const Text('Follow System')),
                  SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.light); Navigator.pop(context); }, child: const Text('Always Light')),
                  SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.dark); Navigator.pop(context); }, child: const Text('Always Dark')),
                ],
              ),
            ),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16.0), child: Text('VpnService Options', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
          ListTile(
            title: const Text('Access Control Mode'), subtitle: Text(accessMode),
            onTap: () => showDialog(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Access Control Mode'),
                children: [
                  SimpleDialogOption(onPressed: () { setState(() => accessMode = 'Allow all apps'); Navigator.pop(context); }, child: const Text('Allow all apps')),
                  SimpleDialogOption(onPressed: () { setState(() => accessMode = 'Allow selected apps'); Navigator.pop(context); }, child: const Text('Allow selected apps')),
                  SimpleDialogOption(onPressed: () { setState(() => accessMode = 'Deny selected apps'); Navigator.pop(context); }, child: const Text('Deny selected apps')),
                ],
              ),
            ),
          ),
          ListTile(
            title: const Text('Access Control Packages'), subtitle: const Text('Pilih aplikasi yang lewat VPN'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppListScreen())),
          ),
        ],
      ),
    );
  }
}

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  List<Application> _apps = [];
  Map<String, bool> _selectedApps = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  void _loadApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true, includeSystemApps: true, onlyAppsWithLaunchIntent: true,
    );
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    setState(() {
      _apps = apps;
      for (var app in apps) { _selectedApps[app.packageName] = false; }
      _isLoading = false;
    });
  }

  void _selectAll(bool value) {
    setState(() { for (var app in _apps) { _selectedApps[app.packageName] = value; } });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Control P...'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'all') _selectAll(true);
              if (value == 'none') _selectAll(false);
              if (value == 'invert') {
                setState(() { for (var app in _apps) { _selectedApps[app.packageName] = !(_selectedApps[app.packageName] ?? false); } });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Select All')),
              const PopupMenuItem(value: 'none', child: Text('Select None')),
              const PopupMenuItem(value: 'invert', child: Text('Select Invert')),
            ],
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _apps.length,
        itemBuilder: (context, index) {
          final app = _apps[index];
          return CheckboxListTile(
            secondary: app is ApplicationWithIcon ? Image.memory(app.icon, width: 40, height: 40) : const Icon(Icons.android, size: 40),
            title: Text(app.appName), subtitle: Text(app.packageName),
            value: _selectedApps[app.packageName] ?? false,
            onChanged: (bool? value) { setState(() { _selectedApps[app.packageName] = value ?? false; }); },
          );
        },
      ),
    );
  }
}
