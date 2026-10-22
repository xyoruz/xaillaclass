import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import 'package:url_launcher/url_launcher.dart';

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
  void _changeTheme(ThemeMode mode) => setState(() => _themeMode = mode);

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
  final FlutterV2ray _flutterV2ray = FlutterV2ray(onStatusChanged: (status, duration, upload, download) {}, onEmitLog: (type, message) {});
  bool isConnected = false;
  List<String> savedConfigs = [];
  String activeConfig = "";

  @override
  void initState() {
    super.initState();
    _loadSavedConfigs();
  }

  Future<void> _loadSavedConfigs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedConfigs = prefs.getStringList('vpn_configs') ?? [];
      if (savedConfigs.isNotEmpty) activeConfig = savedConfigs[0];
    });
  }

  Future<void> _saveConfig(String config) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!savedConfigs.contains(config)) {
      savedConfigs.add(config);
      await prefs.setStringList('vpn_configs', savedConfigs);
      setState(() => activeConfig = config);
    }
  }

  Future<void> _deleteConfig(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedConfigs.removeAt(index);
      if (savedConfigs.isEmpty) activeConfig = "";
    });
    await prefs.setStringList('vpn_configs', savedConfigs);
  }

  Future<void> toggleConnection() async {
    if (activeConfig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih akun terlebih dahulu!')));
      return;
    }

    if (isConnected) {
      await _flutterV2ray.stopV2ray();
      setState(() => isConnected = false);
    } else {
      // Parsing config sederhana (vmess://, trojan://, ss://)
      String parsedConfig = activeConfig;
      if (activeConfig.startsWith('vmess://')) {
        String base64Str = activeConfig.substring(8);
        parsedConfig = utf8.decode(base64.decode(base64Str));
      } else if (activeConfig.startsWith('trojan://') || activeConfig.startsWith('ss://')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format URL ini butuh parser khusus, gunakan format JSON/Vmess untuk tes.')));
        return;
      }

      try {
        V2rayParse parse = await _flutterV2ray.initializeV2ray(parsedConfig, "{}");
        if (parse.success) {
          await _flutterV2ray.startV2ray(
            remark: parse.remark,
            config: parsedConfig,
            proxyOnly: false,
            blockedApps: [],
            bypassSubnets: [],
          );
          setState(() => isConnected = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Config error: ${parse.error}')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal connect: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('🍟 ', style: TextStyle(fontSize: 24)), Text('XAILLA-CLASS', style: TextStyle(fontWeight: FontWeight.bold))]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddAccountDialog(context)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Tombol Connect
            GestureDetector(
              onTap: toggleConnection,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: isConnected ? Colors.green.shade700 : Colors.grey.shade600, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(isConnected ? Icons.shield : Icons.block, size: 50, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(isConnected ? 'Connected' : 'Stopped', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(isConnected ? 'Tap to disconnect' : 'Tap to start', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // List Akun Tersimpan
            if (savedConfigs.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Akun Tersimpan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    ),
                    ...savedConfigs.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String cfg = entry.value;
                      String displayName = cfg.length > 30 ? cfg.substring(0, 30) + '...' : cfg;
                      return RadioListTile<int>(
                        title: Text(displayName, style: const TextStyle(fontSize: 12)),
                        value: idx,
                        groupValue: savedConfigs.indexOf(activeConfig),
                        onChanged: (val) => setState(() => activeConfig = cfg),
                        secondary: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteConfig(idx)),
                      );
                    }).toList(),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.purple),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(onThemeChanged: widget.onThemeChanged))),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info, color: Colors.purple),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(context: context, applicationName: "Xailla Class", applicationVersion: "2.0.0"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Akun Baru'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Paste URL (vmess://...) atau Config JSON/YAML'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _saveConfig(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// --- HALAMAN SETTINGS ---
class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const SettingsScreen({super.key, required this.onThemeChanged});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Interface', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.dark_mode), title: const Text('Dark Mode'), subtitle: const Text('Follow System'),
            onTap: () => showDialog(context: context, builder: (context) => SimpleDialog(
              title: const Text('Pilih Tema'),
              children: [
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.system); Navigator.pop(context); }, child: const Text('Follow System')),
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.light); Navigator.pop(context); }, child: const Text('Always Light')),
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.dark); Navigator.pop(context); }, child: const Text('Always Dark')),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
