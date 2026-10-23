import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static Map<String, String> getFields(String text) {
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
    final f = getFields(t);
    final type = (f['type'] ?? '').toLowerCase();
    final name = f['name'] ?? 'Xailla';
    final server = f['server'] ?? '';
    final port = f['port'] ?? '443';
    final network = (f['network'] ?? 'tcp').toLowerCase();
    final path = f['path'] ?? '/';
    final sni = f['sni'] ?? f['servername'] ?? f['host'] ?? server;
    final host = f['host'] ?? sni;
    final insecure = (f['skip-cert-verify'] ?? 'false').toLowerCase() == 'true';
    final udp = (f['udp'] ?? 'false').toLowerCase() == 'true';

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
          'udp': udp ? 'true' : 'false',
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
          'udp': udp ? 'true' : 'false',
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
          'udp': udp ? 'true' : 'false',
        };
        return 'vmess://${base64Encode(utf8.encode(jsonEncode(m)))}';

      default:
        throw FormatException('tipe "$type" belum didukung');
    }
  }

  static String toYaml(String raw) {
    final t = raw.trim();
    if (isYaml(t)) return t;

    try {
      if (t.startsWith('vmess://')) {
        String body = t.substring(8).replaceAll(RegExp(r'\s+'), '');
        while (body.length % 4 != 0) { body += '='; }
        
        final m = jsonDecode(utf8.decode(base64.decode(base64.normalize(body))));
        
        final name = m['ps'] ?? 'VMess';
        final server = m['add'] ?? '';
        final port = m['port']?.toString() ?? '443';
        final uuid = m['id'] ?? '';
        final net = m['net'] ?? 'tcp';
        final tls = (m['tls'] ?? '').toString().isNotEmpty;
        final path = m['path'] ?? '/';
        final host = m['host'] ?? '';
        final udp = (m['udp'] ?? 'false').toString() == 'true';

        return '''name: $name
server: $server
port: $port
type: vmess
uuid: $uuid
tls: ${tls ? 'true' : 'false'}
network: $net
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: $path
  headers:
    Host: $host''';
      }

      final uri = Uri.parse(t);
      if (uri.scheme == 'trojan') {
        final pass = uri.userInfo;
        final server = uri.host;
        final port = uri.port.toString();
        final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'Trojan';
        final sni = uri.queryParameters['sni'] ?? server;
        final net = uri.queryParameters['type'] ?? 'tcp';
        final path = uri.queryParameters['path'] ?? '/';
        final host = uri.queryParameters['host'] ?? sni;
        final udp = (uri.queryParameters['udp'] ?? 'false') == 'true';

        return '''name: $name
server: $server
port: $port
type: trojan
password: $pass
skip-cert-verify: true
sni: $sni
network: $net
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: $path
  headers:
    Host: $host''';
      }

      if (uri.scheme == 'vless') {
        final uuid = uri.userInfo;
        final server = uri.host;
        final port = uri.port.toString();
        final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'VLESS';
        final sni = uri.queryParameters['sni'] ?? server;
        final tls = (uri.queryParameters['security'] ?? 'none') == 'tls';
        final net = uri.queryParameters['type'] ?? 'tcp';
        final path = uri.queryParameters['path'] ?? '/';
        final host = uri.queryParameters['host'] ?? sni;
        final udp = (uri.queryParameters['udp'] ?? 'false') == 'true';

        return '''name: $name
server: $server
port: $port
type: vless
uuid: $uuid
tls: ${tls ? 'true' : 'false'}
sni: $sni
network: $net
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: $path
  headers:
    Host: $host''';
      }

      if (uri.scheme == 'ss') {
        return '''name: Akun SS
server: ${uri.host}
port: ${uri.port}
type: ss
cipher: aes-256-gcm
password: ${uri.userInfo}
udp: true''';
      }
    } catch (e) {
      print("Gagal parse config: $e");
    }
    return t;
  }

  static ProfileInfo describe(String raw) {
    final t = raw.trim();
    try {
      if (t.startsWith('{')) return const ProfileInfo('Custom JSON', 'json');
      if (isYaml(t)) {
        final f = getFields(t);
        return ProfileInfo(f['name'] ?? 'Tanpa nama', (f['type'] ?? '?').toLowerCase());
      }
      if (t.startsWith('vmess://')) {
        String body = t.substring(8).replaceAll(RegExp(r'\s+'), '');
        while (body.length % 4 != 0) { body += '='; }
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
  ThemeMode _themeMode = ThemeMode.light;

  void _changeTheme(ThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xailla Class',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B1FA2), brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
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

// ======================= MAIN NAVIGATOR =======================

class MainNavigator extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const MainNavigator({super.key, required this.onThemeChanged});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  List<String> savedConfigs = [];
  int selectedIndex = 0;

  late final FlutterV2ray _v2ray;
  bool isConnected = false;
  bool isBusy = false;
  bool isRefreshingPing = false;
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
    setState(() {
      isConnected = connected;
      duration = status.duration.toString();
      downSpeed = int.tryParse(status.downloadSpeed.toString()) ?? 0;
      upSpeed = int.tryParse(status.uploadSpeed.toString()) ?? 0;
      if (!connected) pings = {};
    });
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
      await Permission.notification.request();
      await prefs.setBool('perm_asked', true);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_configs', savedConfigs);
    await prefs.setInt('selected_index', selectedIndex);
  }

  void _addConfig(String rawCombinedConfig) {
    final newConfigs = rawCombinedConfig.split('---').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    setState(() {
      savedConfigs = [...savedConfigs, ...newConfigs];
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
      if (index == -1) {
        savedConfigs = [];
        selectedIndex = 0;
      } else {
        final list = List<String>.from(savedConfigs);
        list.removeAt(index);
        savedConfigs = list;
        if (selectedIndex >= savedConfigs.length) {
          selectedIndex = savedConfigs.isEmpty ? 0 : savedConfigs.length - 1;
        }
      }
      pings = {};
    });
    _saveConfigs();
  }

  void _select(int index) async {
    if (isBusy) return;
    setState(() => selectedIndex = index);
    _saveConfigs();

    if (isConnected) {
      setState(() => isBusy = true);
      _snack('Berganti ke akun lain...');
      
      try {
        _v2ray.stopV2Ray();
        await Future.delayed(const Duration(milliseconds: 500));
        
        final p = ConfigParser.prepare(savedConfigs[index]);
        _v2ray.startV2Ray(remark: p.remark, config: p.config, proxyOnly: false);
      } catch (e) {
        _snack('Gagal berganti akun: $e');
      } finally {
        if (mounted) setState(() => isBusy = false);
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (isBusy) return;
    if (isConnected) {
      _v2ray.stopV2Ray();
      return;
    }
    if (savedConfigs.isEmpty) {
      _snack('Tambah profil dulu di menu Edit Config.');
      return;
    }
    setState(() => isBusy = true);
    try {
      final idx = selectedIndex.clamp(0, savedConfigs.length - 1);
      final p = ConfigParser.prepare(savedConfigs[idx]);
      
      if (await _v2ray.requestPermission()) {
        _v2ray.startV2Ray(remark: p.remark, config: p.config, proxyOnly: false);
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
    if (isRefreshingPing) return;
    setState(() => isRefreshingPing = true);

    for (int i = 0; i < savedConfigs.length; i++) {
      if (!mounted || !isConnected) {
        break;
      }
      try {
        final p = ConfigParser.prepare(savedConfigs[i]);
        final d = await _v2ray.getServerDelay(config: p.config).timeout(const Duration(seconds: 8));
        if (!mounted || !isConnected) break;
        setState(() => pings[i] = d);
      } catch (_) {
        if (mounted && isConnected) setState(() => pings[i] = -1);
      }
    }

    if (mounted) setState(() => isRefreshingPing = false);
  }

  void _goToConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          configs: savedConfigs,
          selectedIndex: selectedIndex,
          isConnected: isConnected,
          isBusy: isBusy,
          pings: pings,
          isRefreshingPing: isRefreshingPing,
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
      ),
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(onThemeChanged: widget.onThemeChanged),
      ),
    );
  }

  void _goToAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Xailla Class',
      applicationVersion: 'v2.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('assets/logo.jpg', width: 40, height: 40, fit: BoxFit.cover),
      ),
      children: [
        const Text('Aplikasi VPN ringan dan elegan untuk kebutuhan koneksi Anda.'),
        const SizedBox(height: 10),
        Text('Created with ❤️', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      isConnected: isConnected,
      isBusy: isBusy,
      duration: duration,
      downSpeed: downSpeed,
      upSpeed: upSpeed,
      onToggle: _toggleConnection,
      onOpenConfig: _goToConfig,
      onOpenSettings: _goToSettings,
      onOpenAbout: _goToAbout,
    );
  }
}

// ======================= HOME SCREEN =======================

class HomeScreen extends StatelessWidget {
  final bool isConnected;
  final bool isBusy;
  final String duration;
  final int downSpeed;
  final int upSpeed;
  final VoidCallback onToggle;
  final VoidCallback onOpenConfig;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.isBusy,
    required this.duration,
    required this.downSpeed,
    required this.upSpeed,
    required this.onToggle,
    required this.onOpenConfig,
    required this.onOpenSettings,
    required this.onOpenAbout,
  });

  String _speed(int bytes) => (bytes / 1024).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      // BoxShadow dihapus agar tidak ada bayangan/tepi hitam
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/logo.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'XAILLA CLASS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.shade600
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? Colors.green : Colors.grey).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isBusy
                                  ? (isConnected ? 'Disconnecting...' : 'Connecting...')
                                  : (isConnected ? 'Connected' : 'Disconnected'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConnected
                                  ? '↓ ${_speed(downSpeed)} KB/s  |  ↑ ${_speed(upSpeed)} KB/s  |  $duration'
                                  : 'Tap to connect',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isBusy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _menuCard(
                context: context,
                icon: Icons.edit_document,
                iconColor: isDark ? Colors.white : Colors.black87,
                title: 'Edit Config',
                subtitle: 'Edit your config here',
                onTap: onOpenConfig,
                cardColor: cardColor,
                textColor: textColor,
              ),
              const SizedBox(height: 12),

              _menuCard(
                context: context,
                icon: Icons.settings,
                iconColor: isDark ? Colors.white : Colors.black87,
                title: 'Settings',
                subtitle: 'App preferences',
                onTap: onOpenSettings,
                cardColor: isDark ? Colors.grey.shade900 : Colors.transparent,
                textColor: textColor,
                isTransparent: true,
              ),
              const SizedBox(height: 12),

              _menuCard(
                context: context,
                icon: Icons.info_outline,
                iconColor: isDark ? Colors.white : Colors.black87,
                title: 'About',
                subtitle: 'Version & information',
                onTap: onOpenAbout,
                cardColor: isDark ? Colors.grey.shade900 : Colors.transparent,
                textColor: textColor,
                isTransparent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    bool isTransparent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTransparent ? Colors.transparent : cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isTransparent ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ======================= PROFIL SCREEN =======================

class ProfileScreen extends StatefulWidget {
  final List<String> configs;
  final int selectedIndex;
  final bool isConnected, isBusy;
  final bool isRefreshingPing;
  final Map<int, int> pings;
  final void Function(int) onSelect;
  final VoidCallback onToggle, onRefreshPing;
  final void Function(String) onAdd;
  final void Function(int, String) onEdit;
  final void Function(int) onDelete;

  const ProfileScreen({
    super.key, required this.configs, required this.selectedIndex,
    required this.isConnected, required this.isBusy, required this.pings,
    required this.isRefreshingPing,
    required this.onSelect, required this.onToggle, required this.onRefreshPing,
    required this.onAdd, required this.onEdit, required this.onDelete,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeTab = 0;

  List<TextEditingController> _controllers = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initConfigs();
  }

  void _initConfigs() {
    if (_isInitialized) return;
    _controllers = [];
    
    if (widget.configs.isNotEmpty) {
      for (var config in widget.configs) {
        _controllers.add(TextEditingController(text: ConfigParser.toYaml(config)));
      }
    } else {
      _controllers.add(TextEditingController());
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    for (var ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _addNewField() async {
    String initialText = '';
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';
      
      if (text.startsWith('vmess://') || text.startsWith('trojan://') || text.startsWith('vless://') || text.startsWith('ss://')) {
        try {
          initialText = ConfigParser.toYaml(text);
        } catch (e) {
          initialText = text;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format link tidak valid, edit manual.')));
          }
        }
      }
    } catch (e) {}

    setState(() {
      _controllers.add(TextEditingController(text: initialText));
    });
  }

  void _saveConfigs() {
    List<String> validConfigs = [];
    List<String> accountNames = [];
    List<String> errors = [];

    for (int i = 0; i < _controllers.length; i++) {
      final rawText = _controllers[i].text.trim();
      if (rawText.isEmpty) continue;

      final blocks = rawText.split('---').map((e) => e.trim()).where((e) => e.isNotEmpty);

      for (var block in blocks) {
        try {
          if (block.startsWith('{')) {
            jsonDecode(block);
          } else if (ConfigParser.isYaml(block)) {
            final f = ConfigParser.getFields(block);
            if ((f['server'] ?? '').isEmpty) throw Exception('Server kosong');
            if ((f['type'] ?? '').isEmpty) throw Exception('Tipe (trojan/vmess) kosong');
          } else {
            final uri = Uri.parse(block);
            if (!['vmess', 'vless', 'trojan', 'ss'].contains(uri.scheme)) {
              throw Exception('Format link tidak dikenali');
            }
          }

          final info = ConfigParser.describe(block);
          final name = info.name;

          if (accountNames.contains(name)) {
            errors.add('Akun "$name" ganda. Ganti nama salah satunya.');
            continue;
          }

          accountNames.add(name);
          validConfigs.add(block);

        } catch (e) {
          errors.add('Format tidak valid pada salah satu akun: ${e.toString().replaceAll('Exception: ', '')}');
        }
      }
    }

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gagal Menyimpan'),
          content: Text(errors.join('\n\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Perbaiki')),
          ],
        ),
      );
      return;
    }

    if (validConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Config tidak boleh kosong')));
      return;
    }

    widget.onDelete(-1);
    widget.onAdd(validConfigs.join('\n---\n'));
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Config berhasil disimpan')));
    Navigator.pop(context);
  }

  void _showMenu(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Hapus Akun Ini'), onTap: () { 
              Navigator.pop(ctx); 
              setState(() {
                _controllers[index].dispose();
                _controllers.removeAt(index);
                if (_controllers.isEmpty) _controllers.add(TextEditingController());
              });
            }),
          ],
        ),
      ),
    );
  }

  List<MapEntry<int, String>> _getDisplayedConfigs() {
    final list = widget.configs.asMap().entries.toList();
    if (_activeTab == 1 || _activeTab == 2) {
      list.sort((a, b) {
        final pingA = widget.pings[a.key] ?? 99999;
        final pingB = widget.pings[b.key] ?? 99999;
        return pingA.compareTo(pingB);
      });
    } else if (_activeTab == 3) {
      list.sort((a, b) {
        final nameA = ConfigParser.describe(a.value).name.toLowerCase();
        final nameB = ConfigParser.describe(b.value).name.toLowerCase();
        return nameA.compareTo(nameB);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Config Editor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: _addNewField,
            ),
            IconButton(
              icon: const Icon(Icons.save, color: Colors.black),
              onPressed: _saveConfigs,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_controllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: GestureDetector(
                  onLongPress: () => _showMenu(context, index),
                  child: TextField(
                    controller: _controllers[index],
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace', 
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    }

    final displayed = _getDisplayedConfigs();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Proxy', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabButton('Select', 0),
                  _tabButton('Best Ping', 1),
                  _tabButton('Fallback', 2),
                  _tabButton('Load Balance', 3),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: widget.configs.isEmpty
                ? const Center(child: Text('Belum ada profil. Tekan + untuk menambah.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayed.length,
                    itemBuilder: (context, i) {
                      final entry = displayed[i];
                      final index = entry.key;
                      final configString = entry.value;
                      
                      final desc = ConfigParser.describe(configString);
                      final isSelected = index == widget.selectedIndex;
                      final ping = widget.pings[index];

                      return Card(
                        elevation: 0,
                        color: isSelected ? Colors.purple.shade900 : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Icon(
                            desc.type == 'vmess' ? Icons.cloud : Icons.security,
                            color: isSelected ? Colors.white : Colors.purple,
                          ),
                          title: Text(
                            desc.name,
                            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : null),
                          ),
                          subtitle: Text(
                            desc.type.toUpperCase(),
                            style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ping != null)
                                Text(
                                  ping == -1 ? 'Timeout' : '$ping',
                                  style: TextStyle(
                                    color: ping == -1 ? Colors.red : (isSelected ? Colors.white : Colors.green),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (isSelected)
                                const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.check_circle, color: Colors.white, size: 20)),
                            ],
                          ),
                          onTap: () => widget.onSelect(index),
                          onLongPress: () => _showMenu(context, index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple.shade900,
        onPressed: widget.isRefreshingPing ? null : () => widget.onRefreshPing(),
        child: widget.isRefreshingPing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.bolt, color: Colors.white),
      ),
    );
  }

  Widget _tabButton(String text, int tabIndex) {
    final isActive = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabIndex;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.purple.shade900 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey, 
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          const ListTile(title: Text('Tema Aplikasi'), subtitle: Text('Ubah mode terang / gelap')),
          ListTile(leading: const Icon(Icons.brightness_auto), title: const Text('Ikuti Sistem'), onTap: () => onThemeChanged(ThemeMode.system)),
          ListTile(leading: const Icon(Icons.light_mode), title: const Text('Terang'), onTap: () => onThemeChanged(ThemeMode.light)),
          ListTile(leading: const Icon(Icons.dark_mode), title: const Text('Gelap'), onTap: () => onThemeChanged(ThemeMode.dark)),
        ],
      ),
    );
  }
}
