import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const XaillaApp());
}

class XaillaApp extends StatefulWidget {
  const XaillaApp({super.key});
  @override
  State<XaillaApp> createState() => _XaillaAppState();
}

class _XaillaAppState extends State<XaillaApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default Dark Mode agar elegan

  void _changeTheme(ThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xailla Class',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B1FA2), brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBA68C8), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: MainNavigator(onThemeChanged: _changeTheme),
    );
  }
}

// --- BOTTOM NAVIGATION ---
class MainNavigator extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const MainNavigator({super.key, required this.onThemeChanged});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  List<String> savedConfigs = [];

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedConfigs = prefs.getStringList('vpn_configs') ?? [];
    });
  }

  void _updateConfigs(List<String> newConfigs) {
    setState(() {
      savedConfigs = newConfigs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(savedConfigs: savedConfigs),
      ProfileScreen(savedConfigs: savedConfigs, onConfigsChanged: _updateConfigs),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Profiles'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// --- HALAMAN UTAMA (HOME) ---
class HomeScreen extends StatefulWidget {
  final List<String> savedConfigs;
  const HomeScreen({super.key, required this.savedConfigs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterV2ray _flutterV2ray = FlutterV2ray(
    onStatusChanged: (status, duration, upload, download) {},
    onEmitLog: (type, message) {},
  );
  bool isConnected = false;
  String activeProfileName = "Belum ada profil dipilih";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('XAILLA CLASS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tombol Koneksi Glowing
            GestureDetector(
              onTap: () {
                setState(() => isConnected = !isConnected);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isConnected
                      ? const LinearGradient(colors: [Colors.greenAccent, Colors.green], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                      color: isConnected ? Colors.green.withOpacity(0.5) : Colors.transparent,
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isConnected ? Icons.power_settings_new : Icons.power_settings_new, size: 80, color: isConnected ? Colors.white : Colors.grey.shade500),
                      const SizedBox(height: 10),
                      Text(
                        isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: TextStyle(color: isConnected ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
            
            // Info Statistik (Simulasi UI)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(Icons.arrow_downward, "0.00", "KB/s", Colors.blue),
                _buildStatCard(Icons.arrow_upward, "0.00", "KB/s", Colors.orange),
                _buildStatCard(Icons.timer, "00:00", "Durasi", Colors.purple),
              ],
            ),
            const SizedBox(height: 40),

            // Kartu Profil Aktif
            Card(
              elevation: 0,
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.dns, color: Colors.purple),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.savedConfigs.isNotEmpty ? "Profil Siap Digunakan" : "Pilih profil di menu Profiles",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// --- HALAMAN PROFIL ---
class ProfileScreen extends StatefulWidget {
  final List<String> savedConfigs;
  final Function(List<String>) onConfigsChanged;

  const ProfileScreen({super.key, required this.savedConfigs, required this.onConfigsChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _addConfig(String config) async {
    if (config.isEmpty) return;
    List<String> newList = List.from(widget.savedConfigs);
    newList.add(config);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_configs', newList);
    widget.onConfigsChanged(newList);
  }

  void _deleteConfig(int index) async {
    List<String> newList = List.from(widget.savedConfigs);
    newList.removeAt(index);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_configs', newList);
    widget.onConfigsChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 30, color: Colors.purple),
            onPressed: () => _showAddDialog(context),
          )
        ],
      ),
      body: widget.savedConfigs.isEmpty
          ? const Center(child: Text("Belum ada profil. Klik + untuk menambah.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.savedConfigs.length,
              itemBuilder: (context, index) {
                String config = widget.savedConfigs[index];
                String displayName = config.length > 30 ? "${config.substring(0, 30)}..." : config;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.vpn_key, color: Colors.white)),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Tap to connect (Coming soon)"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteConfig(index),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Profil Baru'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Paste link (vmess://, vless://, trojan://) atau Config JSON',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              _addConfig(controller.text.trim());
              Navigator.pop(context);
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
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Tampilan', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            onTap: () => showDialog(context: context, builder: (context) => SimpleDialog(
              title: const Text('Pilih Tema'),
              children: [
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.system); Navigator.pop(context); }, child: const Text('Ikuti Sistem')),
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.light); Navigator.pop(context); }, child: const Text('Terang')),
                SimpleDialogOption(onPressed: () { widget.onThemeChanged(ThemeMode.dark); Navigator.pop(context); }, child: const Text('Gelap')),
              ],
            )),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Tentang', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versi Aplikasi'),
            subtitle: Text('2.0.0 (Material 3)'),
          ),
        ],
      ),
    );
  }
}
