import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const XaillaApp());
}

// ======================= PARSER KONFIGURASI =======================

class ProfileInfo {
  final String name;
  final String type;
  const ProfileInfo(this.name, this.type);
}

class Prepared {
  final String remark;
  final String config;
  const Prepared(this.remark, this.config);
}

class ConfigParser {
  static bool isYaml(String t) {
    final lower = t.toLowerCase();
    return lower.contains('server:') && lower.contains('type:');
  }

  static Map<String, String> _fields(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      var l = line.trim();
      if (l.startsWith('- ')) l = l.substring(2).trim();
      final i = l.indexOf(':');
      if (i <= 0) continue;
      final key = l.substring(0, i).trim().toLowerCase();
      var val = l.substring(i + 1).trim();
      if (val.length >= 2 &&
          ((val.startsWith('"') && val.endsWith('"')) ||
              (val.startsWith("'") && val.endsWith("'")))) {
        val = val.substring(1, val.length - 1);
      }
      if (val.isEmpty) continue;
      map.putIfAbsent(key, () => val);
    }
    return map;
  }

  static String _query(Map<String, String> q) {
    return q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  static String toLink(String raw) {
    final t = raw.trim();
    if (!isYaml(t)) return t;
    final f = _fields(t);
    final type = (f['type'] ?? '').toLowerCase();
    final name = f['name'] ?? 'Xailla';
    final server = f['server'] ?? '';
    final port = f['port'] ?? '443';
    final network = (f['network'] ?? 'tcp').toLowerCase();
    final path = f['path'] ?? '/';
    final sni = f['sni'] ?? f['servername'] ?? f['host'] ?? server;
    final host = f['host'] ?? sni;
    final insecure = (f['skip-cert-verify'] ?? 'false').toLowerCase() == 'true';

    if (server.isEmpty) throw const FormatException('server kosong');

    switch (type) {
      case 'trojan':
        final pass = f['password'] ?? '';
        if (pass.isEmpty) throw const FormatException('password kosong');
        final q = <String, String>{
          'security': 'tls',
          'sni': sni,
          'type': network,
          'allowInsecure': insecure ? '1' : '0',
        };
        if (network == 'ws') {
          q['host'] = host;
          q['path'] = path;
        }
        return 'trojan://${Uri.encodeComponent(pass)}@$server:$port?${_query(q)}#${Uri.encodeComponent(name)}';

      case 'vless':
        final uuid = f['uuid'] ?? '';
        if (uuid.isEmpty) throw const FormatException('uuid kosong');
        final tls = (f['tls'] ?? 'false').toLowerCase() == 'true';
        final q = <String, String>{
          'encryption': 'none',
          'security': tls ? 'tls' : 'none',
          'type': network,
        };
        if (tls) {
          q['sni'] = sni;
          q['allowInsecure'] = insecure ? '1' : '0';
        }
        if (network == 'ws') {
          q['host'] = host;
          q['path'] = path;
        }
        return 'vless://$uuid@$server:$port?${_query(q)}#${Uri.encodeComponent(name)}';

      case 'vmess':
        final uuid = f['uuid'] ?? '';
        if (uuid.isEmpty) throw const FormatException('uuid kosong');
        final tls = (f['tls'] ?? 'false').toLowerCase() == 'true';
        final m = <String, dynamic>{
          'v': '2',
          'ps': name,
          'add': server,
          'port': port,
          'id': uuid,
          'aid': f['alterid'] ?? '0',
          'scy': f['cipher'] ?? 'auto',
          'net': network,
          'type': 'none',
          'host': network == 'ws' ? host : '',
          'path': network == 'ws' ? path : '',
          'tls': tls ? 'tls' : '',
          'sni': tls ? sni : '',
        };
        return 'vmess://${base64Encode(utf8.encode(jsonEncode(m)))}';

      default:
        throw FormatException('tipe "$type" belum didukung');
    }
  }

  static ProfileInfo describe(String raw) {
    final t = raw.trim();
    try {
      if (t.startsWith('{')) return const ProfileInfo('Custom JSON', 'json');
      if (isYaml(t)) {
        final f = _fields(t);
        return ProfileInfo(f['name'] ?? 'Tanpa nama', (f['type'] ?? '?').toLowerCase());
      }
      if (t.startsWith('vmess://')) {
        final body = t.substring(8);
        final m = jsonDecode(utf8.decode(base64.decode(base64.normalize(body))));
        return ProfileInfo((m['ps'] ?? 'VMess').toString(), 'vmess');
      }
      final idx = t.indexOf('://');
      final scheme = idx > 0 ? t.substring(0, idx) : '?';
      final hash = t.indexOf('#');
      final name = hash >= 0 ? Uri.decodeComponent(t.substring(hash + 1)) : scheme;
      return ProfileInfo(name.isEmpty ? scheme : name, scheme);
    } catch (_) {
      return const ProfileInfo('Profil tidak dikenal', '?');
    }
  }

  static Prepared prepare(String raw) {
    final t = raw.trim();
    if (t.startsWith('{')) return Prepared('Xailla', t);
    final link = toLink(t);
    final parsed = FlutterV2ray.parseFromURL(link);
    return Prepared(parsed.remark, parsed.getFullConfiguration());
  }
}

// ======================= APP =======================

class XaillaApp extends StatefulWidget {
  const XaillaApp({super.key});
  @override
  State<XaillaApp> createState() => _XaillaAppState();
}

class _XaillaAppState extends State<XaillaApp> {
  ThemeMode _themeMode = ThemeMode.dark;

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

// ======================= NAVIGATOR + KONTROLER VPN =======================

class MainNavigator extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const MainNavigator({super.key, required this.onThemeChanged});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  List<String> savedConfigs = [];
  int selectedIndex = 0;

  late final FlutterV2ray _v2ray;
  bool isConnected = false;
  bool isBusy = false;
  String duration = '00:00:00';
  int downSpeed = 0;
  int upSpeed = 0;
  Map<int, int> pings = {};

  @override
  void initState() {
    super.initState();
    _v2ray = FlutterV2ray(onStatusChanged: _onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onStatus(dynamic status) {
    if (!mounted) return;
    final connected = status.state.toString() == 'CONNECTED';
    final was = isConnected;
    setState(() {
      isConnected = connected;
      duration = status.duration.toString();
      downSpeed = int.tryParse(status.downloadSpeed.toString()) ?? 0;
      upSpeed = int.tryParse(status.uploadSpeed.toString()) ?? 0;
      if (!connected) pings = {};
    });
    if (connected && !was) _measurePings();
  }

  Future<void> _init() async {
    await _v2ray.initializeV2Ray();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      savedConfigs = prefs.getStringList('vpn_configs') ?? [];
      selectedIndex = prefs.getInt('selected_index') ?? 0;
      if (selectedIndex >= savedConfigs.length) selectedIndex = 0;
    });
    if (!(prefs.getBool('perm_asked') ?? false)) {
      await _askPermissions(prefs);
    }
  }

  Future<void> _askPermissions(SharedPreferences prefs) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin Aplikasi'),
        content: const Text(
          'Xailla Class membutuhkan izin berikut agar berjalan penuh:\n\n'
          '• VPN: untuk membuat koneksi VPN\n'
          '• Notifikasi: untuk status koneksi saat berjalan di latar belakang\n\n'
          'Tekan Izinkan, lalu setujui permintaan Android berikutnya.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Izinkan')),
        ],
      ),
    );
    await Permission.notification.request();
    await _v2ray.requestPermission();
    await prefs.setBool('perm_asked', true);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_configs', savedConfigs);
    await prefs.setInt('selected_index', selectedIndex);
  }

  void _addConfig(String config) {
    setState(() {
      savedConfigs = [...savedConfigs, config];
      selectedIndex = savedConfigs.length - 1;
    });
    _saveConfigs();
  }

  void _editConfig(int index, String config) {
    setState(() {
      final list = List<String>.from(savedConfigs);
      list[index] = config;
      savedConfigs = list;
    });
    _saveConfigs();
  }

  void _deleteConfig(int index) {
    setState(() {
      final list = List<String>.from(savedConfigs);
      list.removeAt(index);
      savedConfigs = list;
      pings = {};
      if (selectedIndex >= savedConfigs.length) {
        selectedIndex = savedConfigs.isEmpty ? 0 : savedConfigs.length - 1;
      }
    });
    _saveConfigs();
  }

  void _select(int index) {
    if (isConnected) {
      _snack('Putuskan koneksi dulu, lalu pilih profil lain.');
      return;
    }
    setState(() => selectedIndex = index);
    _saveConfigs();
  }

  Future<void> _toggleConnection() async {
    if (isBusy) return;
    if (isConnected) {
      _v2ray.stopV2Ray();
      return;
    }
    if (savedConfigs.isEmpty) {
      _snack('Tambah profil dulu di menu Profiles.');
      return;
    }
    setState(() => isBusy = true);
    try {
      final idx = selectedIndex.clamp(0, savedConfigs.length - 1);
      final p = ConfigParser.prepare(savedConfigs[idx]);
      if (await _v2ray.requestPermission()) {
        _v2ray.startV2Ray(
          remark: p.remark,
          config: p.config,
          proxyOnly: false,
        );
      } else {
        _snack('Izin VPN ditolak.');
      }
    } catch (e) {
      _snack('Gagal menyambung: $e');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _measurePings() async {
    for (int i = 0; i < savedConfigs.length; i++) {
      if (!mounted || !isConnected) return;
      try {
        final p = ConfigParser.prepare(savedConfigs[i]);
        final d = await _v2ray
            .getServerDelay(config: p.config)
            .timeout(const Duration(seconds: 8));
        if (!mounted || !isConnected) return;
        setState(() => pings[i] = d);
      } catch (_) {
        if (mounted && isConnected) setState(() => pings[i] = -1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileName = savedConfigs.isEmpty
        ? 'Belum ada profil dipilih'
        : ConfigParser.describe(savedConfigs[selectedIndex]).name;

    final screens = [
      HomeScreen(
        isConnected: isConnected,
        isBusy: isBusy,
        duration: duration,
        downSpeed: downSpeed,
        upSpeed: upSpeed,
        profileName: profileName,
        onToggle: _toggleConnection,
      ),
      ProfileScreen(
        configs: savedConfigs,
        selectedIndex: selectedIndex,
        isConnected: isConnected,
        isBusy: isBusy,
        pings: pings,
        onSelect: _select,
        onToggle: _toggleConnection,
        onRefreshPing: () {
          setState(() => pings = {});
          _measurePings();
        },
        onAdd: _addConfig,
        onEdit: _editConfig,
        onDelete: _deleteConfig,
      ),
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

// ======================= HOME =======================

class HomeScreen extends StatelessWidget {
  final bool isConnected;
  final bool isBusy;
  final String duration;
  final int downSpeed;
  final int upSpeed;
  final String profileName;
  final VoidCallback onToggle;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.isBusy,
    required this.duration,
    required this.downSpeed,
    required this.upSpeed,
    required this.profileName,
    required this.onToggle,
  });

  String _speed(int bytes) => (bytes / 1024).toStringAsFixed(2);

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
            GestureDetector(
              onTap: onToggle,
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
                      isBusy
                          ? const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 4))
                          : Icon(Icons.power_settings_new, size: 80, color: isConnected ? Colors.white : Colors.grey.shade500),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard(Icons.arrow_downward, _speed(downSpeed), 'KB/s', Colors.blue),
                _statCard(Icons.arrow_upward, _speed(upSpeed), 'KB/s', Colors.orange),
                _statCard(Icons.timer, isConnected ? duration : '00:00:00', 'Durasi', Colors.purple),
              ],
            ),
            const SizedBox(height: 40),
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
                        profileName,
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

  Widget _statCard(IconData icon, String value, String label, Color color) {
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

// ======================= PROFIL (DAFTAR PROXY + PING) =======================

class ProfileScreen extends StatelessWidget {
  final List<String> configs;
  final int selectedIndex;
  final bool isConnected;
  final bool isBusy;
  final Map<int, int> pings;
  final void Function(int) onSelect;
  final VoidCallback onToggle;
  final VoidCallback onRefreshPing;
  final void Function(String) onAdd;
  final void Function(int, String) onEdit;
  final void Function(int) onDelete;

  const ProfileScreen({
    super.key,
    required this.configs,
    required this.selectedIndex,
    required this.isConnected,
    required this.isBusy,
    required this.pings,
    required this.onSelect,
    required this.onToggle,
    required this.onRefreshPing,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _openEditor(BuildContext context, {int? index}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ConfigEditorScreen(initial: index == null ? '' : configs[index]),
      ),
    );
    if (result == null) return;
    if (index == null) {
      onAdd(result);
    } else {
      onEdit(index, result);
    }
  }

  void _showMenu(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(context, index: index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // === LOGIKA BARU: JIKA VPN OFF, TAMPILKAN CONFIG EDITOR ===
    if (!isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Config Editor'),
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_outline, color: Colors.grey),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hubungkan VPN (Home) terlebih dahulu untuk membuka daftar profil.')),
                );
              },
            ),
          ],
        ),
        // Menampilkan Editor (Read-only karena tidak ada aksi simpan)
        body: const ConfigEditorScreen(initial: '', isReadOnly: true),
      );
    }

    // === LOGIKA ASLI (JIKA VPN ON): TAMPILKAN DAFTAR PROXY ===
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(context),
          ),
        ],
      ),
      body: configs.isEmpty
          ? const Center(child: Text('Belum ada profil. Tekan + untuk menambah.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final desc = ConfigParser.describe(configs[index]);
                final isSelected = index == selectedIndex;
                final ping = pings[index];

                return Card(
                  elevation: 0,
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      desc.type == 'vmess' ? Icons.cloud : Icons.security,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                    title: Text(
                      desc.name,
                      style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(desc.type.toUpperCase()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ping != null)
                          Text(
                            ping == -1 ? 'Timeout' : '$ping ms',
                            style: TextStyle(
                              color: ping == -1 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ),
                      ],
                    ),
                    onTap: () => onSelect(index),
                    onLongPress: () => _showMenu(context, index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.bolt, color: Colors.white),
      ),
    );
  }
}

// ======================= CONFIG EDITOR =======================

class ConfigEditorScreen extends StatefulWidget {
  final String initial;
  final bool isReadOnly;
  
  const ConfigEditorScreen({
    super.key, 
    required this.initial,
    this.isReadOnly = false,
  });

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  late TextEditingController _controller;

  static const String _trojanTpl = 'name: Profil Baru\nserver: 1.2.3.4\nport: 443\ntype: trojan\npassword: passkamu\nsni: domain.com\nnetwork: ws\nws-opts:\n  path: /trojan\n  headers:\n    Host: domain.com';
  static const String _vlessTpl = 'name: Profil Baru\nserver: 1.2.3.4\nport: 443\ntype: vless\nuuid: isi-uuid-kamu\ntls: true\nsni: domain.com\nnetwork: ws\nws-opts:\n  path: /vless\n  headers:\n    Host: domain.com';
  static const String _vmessTpl = 'name: Profil Baru\nserver: 1.2.3.4\nport: 443\ntype: vmess\nuuid: isi-uuid-kamu\ntls: true\nnetwork: ws\nws-opts:\n  path: /vmess\n  headers:\n    Host: domain.com';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertTemplate(String tpl) {
    if (widget.isReadOnly) return;
    final current = _controller.text.trim();
    setState(() {
      _controller.text = current.isEmpty ? tpl : '$current\n\n$tpl';
    });
  }

  void _showTemplateDialog() {
    if (widget.isReadOnly) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Template Trojan'),
              onTap: () { Navigator.pop(ctx); _insertTemplate(_trojanTpl); },
            ),
            ListTile(
              leading: const Icon(Icons.shield),
              title: const Text('Template VLESS'),
              onTap: () { Navigator.pop(ctx); _insertTemplate(_vlessTpl); },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Template VMess'),
              onTap: () { Navigator.pop(ctx); _insertTemplate(_vmessTpl); },
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config tidak boleh kosong')),
      );
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Editor'),
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.library_add),
              tooltip: 'Template',
              onPressed: _showTemplateDialog,
            ),
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          readOnly: widget.isReadOnly,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: widget.isReadOnly 
                ? 'Hubungkan VPN terlebih dahulu untuk mengedit'
                : 'Tempelkan link (vmess://, trojan://, dll) atau format YAML (server:, type:) di sini...',
            filled: widget.isReadOnly,
            fillColor: widget.isReadOnly ? Colors.grey.withOpacity(0.1) : null,
          ),
        ),
      ),
    );
  }
}

// ======================= SETTINGS =======================

class SettingsScreen extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;
  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Tema Aplikasi'),
            subtitle: Text('Ubah mode terang / gelap'),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: const Text('Ikuti Sistem'),
            onTap: () => onThemeChanged(ThemeMode.system),
          ),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text('Terang'),
            onTap: () => onThemeChanged(ThemeMode.light),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Gelap'),
            onTap: () => onThemeChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}
