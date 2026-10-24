import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';

// =====================================================================
//  XAILLA CLASS — VPN Client · v2.3.1 (STABILITY PATCH)
//  Bug & fungsi diperbaiki, desain asli dipertahankan:
//   1. Layar Proxy kini LIVE — status/ping/banner update real-time
//      (dulu: nilai beku karena lewat route terpisah)
//   2. Kecepatan/durasi tampil benar, tidak lagi selalu 0
//   3. Status CONNECTING dikenali → tidak bisa dobel-connect
//   4. Ganti akun saat terhubung: menunggu VPN benar-benar berhenti
//   5. Ping jalan normal, hasil tersimpan + chip berwarna
//   6. Simpan config atomik; pilihan akun tidak melompat ke terakhir
//   7. Hapus dari list = benar-benar terhapus + putus VPN bila aktif
//   8. Dark mode konsisten di semua layar + tema tersimpan permanen
//   9. Parser: vmess url-safe base64, port default 443, SS legacy +
//      SIP002, trojan skip-cert-verify mengikuti link, SS bisa connect
//  10. Tab sort kini benar-benar beda fungsi + keterangan
//  11. Ganti akun TANPA lompat layar — daftar Proxy tetap tampil,
//      banner berubah halus jadi "Berganti akun..." (tanpa SnackBar)
//  12. Editor dibuka manual lewat ikon edit di AppBar; tidak ada lagi
//      perpindahan layar otomatis yang terasa seperti pindah "tab"
//  13. Banner "VPN Aktif" di layar Proxy DIHAPUS — tampilan lebih
//      bersih; umpan balik ganti akun kini spinner kecil di kartu
//      akun yang dipilih (memutus cukup dari layar Home)
//  14. Tab sortir (Select/Best Ping/Fallback/Load Balance) kini
//      TERSIMPAN permanen — tutup Proxy, buka lagi dari Home, bahkan
//      restart aplikasi: tetap di tab terakhir. Hanya berubah bila
//      pengguna sendiri menekan tab lain.
//  15. Layar Settings RINGKAS — menu tidak lagi besar: baris padat,
//      ikon kecil, dropdown pilihan gaya aplikasi referensi.
//  16. FITUR BARU: Dark Mode 3 opsi (Follow System / Always Light /
//      Always Dark) + section VpnService Options (Root Tethering
//      nonaktif — butuh root) + Access Control Mode (Allow all /
//      Allow selected / Deny selected).
//  17. FITUR BARU: halaman Access Control Packages — daftar semua
//      aplikasi + cari + Select All/None/Invert + filter System Apps
//      + sortir Name/Package/Install/Update (+ Reverse) + impor/
//      ekspor clipboard. Tersimpan permanen & otomatis dipakai saat
//      VPN tersambung (plugin flutter_v2ray: parameter blockedApps).
//
//  18. Settings disamakan dengan foto referensi: judul "App", section
//      Interface & VpnService Options, Dark Mode dan Access Control Mode
//      kini dropdown popup (opsi terpilih berlatar ungu), Root Tethering
//      nonaktif. Halaman Access Control Packages: ikon Search di AppBar,
//      menu titik tiga dengan submenu Filter / Sort / External, ikon
//      aplikasi di daftar, kotak centang di kanan.
//  19. FIX COMPILE: properti device_apps yang benar adalah
//      installTimeMillis / updateTimeMillis (dulu installTime/updateTime).
//      Hasil gagal-muat daftar aplikasi tidak lagi di-cache.
//  20. DUKUNGAN ARSITEKTUR: build kini mencakup 32-bit (armeabi-v7a)
//      DAN 64-bit (arm64-v8a) + x86_64 untuk emulator. Terverifikasi
//      langsung di paket flutter_v2ray 1.0.10: native library
//      (libtun2socks.so + libv2ray.aar berisi libgojni.so) TERSEDIA
//      untuk keempat ABI — jadi tidak ada pengorbanan apa pun.
//      Kuncinya di android/app/build.gradle (lihat CATATAN BUILD
//      butir 3) dan perintah build (butir 4-5).
//  21. PATCH STABILITAS: aplikasi jauh lebih tahan banting —
//      (a) error async tak terduga dari plugin tidak lagi mematikan
//      aplikasi (global error guard di main()); (b) init inti VPN
//      yang gagal tidak lagi menggagalkan pemuatan config & izin;
//      (c) callback status VPN dibungkus try/catch — payload aneh
//      dari plugin diabaikan; (d) semua tulis SharedPreferences
//      dibungkus try/catch (disk penuh tidak bikin crash); (e) ganti
//      akun/menyambung memvalidasi ulang daftar & mounted setelah
//      await (race saat daftar berubah di tengah proses); (f) ping
//      test pakai snapshot daftar dan isRefreshingPing dijamin selalu
//      reset (FAB tidak bisa mati permanen); (g) posisi dropdown
//      Settings dijepit dalam batas layar; (h) import/export
//      clipboard aman; (i) sortir Load Balance tanpa jank.
//
//  CATATAN BUILD (WAJIB untuk fitur Access Control):
//   1) flutter pub add device_apps
//   2) Tambahkan di android/app/src/main/AndroidManifest.xml:
//      <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>
//   3) ARSITEKTUR — di android/app/build.gradle, di dalam defaultConfig,
//      pastikan tidak ada abiFilters yang hanya menyebut 64-bit. Agar
//      eksplisit, sebutkan:
//          ndk {
//              abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
//          }
//      armeabi-v7a = HP 32-bit lama · arm64-v8a = HP modern 64-bit ·
//      x86_64 = emulator PC. minSdk 21 (Android 5.0+) sudah diatur
//      plugin flutter_v2ray.
//   4) APK SERBA BISA — 1 file terpasang di SEMUA HP (32/64-bit):
//          flutter build apk --release
//   5) APK TERPISAH PER ARSITEKTUR — ukuran lebih kecil:
//          flutter build apk --release --split-per-abi
//      → app-armeabi-v7a-release.apk : HP 32-bit lama (dan tetap
//        terpasang di HP 64-bit berkat backward compatibility)
//      → app-arm64-v8a-release.apk   : HP modern 64-bit (optimal)
//      → app-x86_64-release.apk      : emulator di PC
//      Catatan: APK arm64-v8a TIDAK bisa terpasang di HP 32-bit —
//      kebalikannya tidak berlaku (lihat referensi screenshot).
// =====================================================================

const String appVersion = 'v2.3.1';

void main() {
  // PATCH STABILITAS: error tak tertangkap (mis. dari callback plugin
  // atau Future tanpa catch) TIDAK LAGI MEMATIKAN aplikasi. Dulu satu
  // error async kecil = layar mati langsung; kini hanya dicatat di log.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object e, StackTrace st) {
    debugPrint('Error tak tertangkap (diabaikan): $e');
    return true; // dianggap tertangani — aplikasi tetap hidup
  };
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

  /// FIX: dekoder base64 yang tahan url-safe (- _) dan padding hilang.
  /// base64.normalize() tidak mengubah - dan _ → vmess url-safe crash.
  static List<int> b64decode(String input) {
    var b = input.trim().replaceAll(RegExp(r'\s+'), '');
    b = b.replaceAll('-', '+').replaceAll('_', '/');
    while (b.length % 4 != 0) {
      b += '=';
    }
    return base64.decode(b);
  }

  static String _query(Map<String, String> q) {
    return q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  /// Quote nilai agar aman untuk YAML sederhana milik aplikasi ini
  /// (nama/password sering mengandung spasi, ':', '#', atau kutip).
  static String _y(dynamic v) {
    final s = v.toString();
    final needs = s.contains(':') ||
        s.contains('#') ||
        s.contains("'") ||
        s.contains('"') ||
        s.contains(' ') ||
        s.contains('\n');
    if (!needs) return s;
    return "'" + s.replaceAll("'", "''") + "'";
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
        final aid = int.tryParse(f['alterid'] ?? '0') ?? 0;
        final portNum = int.tryParse(port) ?? port;
        final m = <String, dynamic>{
          'v': '2',
          'ps': name,
          'add': server,
          'port': portNum,
          'id': uuid,
          'aid': aid,
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

      // FIX: dulu tipe "ss" ditolak toLink → akun SS dari YAML tidak
      // pernah bisa tersambung. Kini dibuat link format SIP002.
      case 'ss':
        final pass = f['password'] ?? '';
        final cipher = f['cipher'] ?? 'aes-256-gcm';
        if (pass.isEmpty) throw const FormatException('password kosong');
        final userinfo = base64Encode(utf8.encode('$cipher:$pass'));
        return 'ss://$userinfo@$server:$port#${Uri.encodeComponent(name)}';

      default:
        throw FormatException('tipe "$type" belum didukung');
    }
  }

  // FIX: parsing link ss yang benar (legacy full-base64 + SIP002).
  // Dulu cipher hardcode "aes-256-gcm" & password salah → SS mati total.
  static Map<String, String>? parseSS(String link) {
    try {
      var body = link.trim();
      String name = 'Akun SS';
      final hash = body.indexOf('#');
      if (hash >= 0) {
        final frag = Uri.decodeComponent(body.substring(hash + 1));
        if (frag.isNotEmpty) name = frag;
        body = body.substring(0, hash);
      }
      if (body.toLowerCase().startsWith('ss://')) body = body.substring(5);
      String userInfo, hostPort;
      if (body.contains('@')) {
        // SIP002: ss://base64(cipher:pass)@host:port
        final at = body.lastIndexOf('@');
        userInfo = body.substring(0, at);
        hostPort = body.substring(at + 1);
        try {
          userInfo = utf8.decode(b64decode(userInfo));
        } catch (_) {
          // userinfo plain (jarang) — biarkan apa adanya
        }
      } else {
        // Legacy: ss://base64(cipher:pass@host:port)
        final decoded = utf8.decode(b64decode(body));
        final at = decoded.lastIndexOf('@');
        if (at <= 0) return null;
        userInfo = decoded.substring(0, at);
        hostPort = decoded.substring(at + 1);
      }
      final ci = userInfo.indexOf(':');
      if (ci <= 0) return null;
      final cipher = userInfo.substring(0, ci);
      final pass = userInfo.substring(ci + 1);
      String host;
      int? port;
      if (hostPort.startsWith('[')) {
        // IPv6: [::1]:443
        final close = hostPort.indexOf(']');
        if (close < 0) return null;
        host = hostPort.substring(1, close);
        port = int.tryParse(hostPort.substring(close + 2));
      } else {
        final colon = hostPort.lastIndexOf(':');
        if (colon <= 0) return null;
        host = hostPort.substring(0, colon);
        port = int.tryParse(hostPort.substring(colon + 1));
      }
      if (host.isEmpty || port == null || port <= 0 || port > 65535) return null;
      if (cipher.isEmpty || pass.isEmpty) return null;
      return {
        'name': name,
        'server': host,
        'port': port.toString(),
        'cipher': cipher,
        'password': pass,
      };
    } catch (_) {
      return null;
    }
  }

  static String toYaml(String raw) {
    final t = raw.trim();
    if (isYaml(t)) return t;

    try {
      final lower = t.toLowerCase();
      if (lower.startsWith('vmess://')) {
        final m = jsonDecode(utf8.decode(b64decode(t.substring(8)))) as Map<String, dynamic>;

        final name = (m['ps'] ?? 'VMess').toString();
        final server = (m['add'] ?? '').toString();
        final rawPort = (m['port'] ?? 443).toString();
        // FIX: port kosong/0 → 443 (dulu lolos & bikin config rusak)
        final port = (int.tryParse(rawPort) ?? 0) <= 0 ? '443' : rawPort;
        final uuid = (m['id'] ?? '').toString();
        final net = (m['net'] ?? 'tcp').toString();
        final tls = (m['tls'] ?? '').toString().isNotEmpty;
        final path = (m['path'] ?? '/').toString();
        final host = (m['host'] ?? '').toString();
        final udp = (m['udp'] ?? 'false').toString() == 'true';

        return '''name: ${_y(name)}
server: ${_y(server)}
port: $port
type: vmess
uuid: ${_y(uuid)}
tls: ${tls ? 'true' : 'false'}
network: ${_y(net)}
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: ${_y(path)}
  headers:
    Host: ${_y(host)}''';
      }

      final uri = Uri.tryParse(t);
      if (uri == null) return t;
      // FIX: tanpa port, uri.port = 0 → config port 0 → gagal connect
      final port = uri.port == 0 ? 443 : uri.port;

      if (uri.scheme == 'trojan') {
        final pass = uri.userInfo;
        final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'Trojan';
        final sni = uri.queryParameters['sni'] ?? uri.host;
        final net = uri.queryParameters['type'] ?? 'tcp';
        final path = uri.queryParameters['path'] ?? '/';
        final host = uri.queryParameters['host'] ?? sni;
        final udp = (uri.queryParameters['udp'] ?? 'false') == 'true';
        // FIX: dulu selalu true; kini mengikuti parameter link
        final insecure = (uri.queryParameters['allowInsecure'] ?? '0') == '1';

        return '''name: ${_y(name)}
server: ${_y(uri.host)}
port: $port
type: trojan
password: ${_y(pass)}
skip-cert-verify: ${insecure ? 'true' : 'false'}
sni: ${_y(sni)}
network: ${_y(net)}
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: ${_y(path)}
  headers:
    Host: ${_y(host)}''';
      }

      if (uri.scheme == 'vless') {
        final uuid = uri.userInfo;
        final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'VLESS';
        final sni = uri.queryParameters['sni'] ?? uri.host;
        final security = uri.queryParameters['security'] ?? 'none';
        // FIX: security=reality juga butuh TLS (dulu dianggap none)
        final tls = security == 'tls' || security == 'reality';
        final net = uri.queryParameters['type'] ?? 'tcp';
        final path = uri.queryParameters['path'] ?? '/';
        final host = uri.queryParameters['host'] ?? sni;
        final udp = (uri.queryParameters['udp'] ?? 'false') == 'true';
        final insecure = (uri.queryParameters['allowInsecure'] ?? '0') == '1';

        return '''name: ${_y(name)}
server: ${_y(uri.host)}
port: $port
type: vless
uuid: ${_y(uuid)}
tls: ${tls ? 'true' : 'false'}
sni: ${_y(sni)}
skip-cert-verify: ${insecure ? 'true' : 'false'}
network: ${_y(net)}
udp: ${udp ? 'true' : 'false'}
ws-opts:
  path: ${_y(path)}
  headers:
    Host: ${_y(host)}''';
      }

      if (uri.scheme == 'ss') {
        final m = parseSS(t);
        if (m == null) return t;
        return '''name: ${_y(m['name']!)}
server: ${_y(m['server']!)}
port: ${m['port']}
type: ss
cipher: ${_y(m['cipher']!)}
password: ${_y(m['password']!)}
udp: true''';
      }
    } catch (e) {
      print('Gagal parse config: $e');
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
      final lower = t.toLowerCase();
      if (lower.startsWith('vmess://')) {
        final m = jsonDecode(utf8.decode(b64decode(t.substring(8)))) as Map<String, dynamic>;
        return ProfileInfo((m['ps'] ?? 'VMess').toString(), 'vmess');
      }
      if (lower.startsWith('ss://')) {
        final m = parseSS(t);
        return ProfileInfo(m?['name'] ?? 'Akun SS', 'ss');
      }
      final idx = t.indexOf('://');
      final scheme = idx > 0 ? t.substring(0, idx).toLowerCase() : '?';
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
    try {
      final link = toLink(t);
      final parsed = FlutterV2ray.parseFromURL(link);
      return Prepared(parsed.remark, parsed.getFullConfiguration());
    } catch (e) {
      throw FormatException('Config tidak valid: $e');
    }
  }
}

// ======================= APP =======================

class XaillaApp extends StatefulWidget {
  const XaillaApp({super.key});
  @override
  State<XaillaApp> createState() => _XaillaAppState();
}

class _XaillaAppState extends State<XaillaApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // FIX: tema kini tersimpan permanen (dulu hilang saat aplikasi dibuka ulang)
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_mode');
    if (!mounted) return;
    setState(() {
      _themeMode = (idx != null && idx >= 0 && idx < ThemeMode.values.length)
          ? ThemeMode.values[idx]
          : ThemeMode.system;
    });
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persistTheme(mode);
  }

  // PATCH STABILITAS: tulis preferensi dibungkus try/catch.
  Future<void> _persistTheme(ThemeMode mode) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('theme_mode', mode.index);
    } catch (_) {}
  }

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
      home: MainNavigator(onThemeChanged: _changeTheme, themeMode: _themeMode),
    );
  }
}

// ======================= INVENTARIS APLIKASI =======================

/// Info ringkas satu aplikasi terpasang (untuk Access Control).
/// Sengaja BUKAN tipe `Application` milik device_apps supaya UI
/// tidak bergantung langsung pada tipe package.
class VpnAppInfo {
  final String name;
  final String packageName;
  final bool systemApp;
  final int installTime;
  final int updateTime;
  final Uint8List? icon;
  const VpnAppInfo({
    required this.name,
    required this.packageName,
    required this.systemApp,
    required this.installTime,
    required this.updateTime,
    this.icon,
  });
}

/// Memuat daftar aplikasi terpasang lalu di-cache sepanjang sesi.
/// Dua mode: tanpa ikon (ringan, dipakai saat VPN menyambung) dan
/// dengan ikon (dipakai halaman Access Control Packages).
class AppInventory {
  static List<VpnAppInfo>? _cache;
  static bool _cacheHasIcons = false;

  static Future<List<VpnAppInfo>> load({bool withIcons = false}) async {
    final cached = _cache;
    if (cached != null && (!withIcons || _cacheHasIcons)) return cached;
    List<VpnAppInfo> result = [];
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        includeAppIcons: withIcons,
        onlyAppsWithLaunchIntent: false,
      );
      result = [
        for (final a in apps)
          VpnAppInfo(
            name: a.appName.isEmpty ? a.packageName : a.appName,
            packageName: a.packageName,
            systemApp: a.systemApp,
            // FIX: nama properti device_apps adalah installTimeMillis /
            // updateTimeMillis (dulu installTime/updateTime → error compile).
            installTime: a.installTimeMillis,
            updateTime: a.updateTimeMillis,
            icon: a is ApplicationWithIcon ? a.icon : null,
          ),
      ];
      result.sort(
          (x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));
    } catch (_) {
      // Gagal memuat (mis. permission QUERY_ALL_PACKAGES belum ada).
      result = [];
    }
    // FIX: hasil kosong (gagal) tidak lagi di-cache → bisa dicoba ulang.
    if (result.isNotEmpty) {
      _cache = result;
      _cacheHasIcons = withIcons;
    }
    return result;
  }
}

// ======================= MAIN NAVIGATOR =======================

class MainNavigator extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode themeMode;
  const MainNavigator({super.key, required this.onThemeChanged, required this.themeMode});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

/// Data segar untuk ProfileScreen. Layar itu berada di route terpisah,
/// sehingga nilai biasa yang diberikan saat push TIDAK akan pernah
/// ter-update (penyebab ping & status basi). Lewat getter + Listenable
/// inilah layar Proxy menjadi live.
class ProxyScreenData {
  final List<String> configs;
  final int selectedIndex;
  final bool isConnected;
  final bool isConnecting;
  final bool isBusy;
  final bool isDisconnecting;
  final bool isSwitching;
  final bool isRefreshingPing;
  final String duration;
  final Map<int, int> pings;
  const ProxyScreenData({
    required this.configs,
    required this.selectedIndex,
    required this.isConnected,
    required this.isConnecting,
    required this.isBusy,
    required this.isDisconnecting,
    required this.isSwitching,
    required this.isRefreshingPing,
    required this.duration,
    required this.pings,
  });
}

class _MainNavigatorState extends State<MainNavigator> {
  List<String> savedConfigs = [];
  int selectedIndex = 0;

  late final FlutterV2ray _v2ray;
  bool isConnected = false;
  bool isConnecting = false;
  bool isBusy = false;
  bool isDisconnecting = false; // sedang memutus (tap Putuskan)
  bool isSwitching = false; // sedang pindah akun saat VPN aktif
  bool isRefreshingPing = false;
  String duration = '00:00:00';
  int downSpeed = 0;
  int upSpeed = 0;
  Map<int, int> pings = {};

  // Access Control (fitur v2.1.0, sesuai foto referensi):
  // 0 = Allow all apps, 1 = Allow selected apps, 2 = Deny selected apps.
  int accessMode = 0;
  List<String> accessPackages = [];

  // Listener untuk route ProfileScreen agar ikut rebuild saat state berubah.
  final ChangeNotifier _proxyListeners = ChangeNotifier();

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _proxyListeners.notifyListeners();
  }

  @override
  void initState() {
    super.initState();
    _v2ray = FlutterV2ray(onStatusChanged: _onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _proxyListeners.dispose();
    super.dispose();
  }

  // FIX: deteksi status kini tahan terhadap format enum package dan
  // mengenali CONNECTING (dulu diabaikan → tombol bisa dobel-connect).
  void _onStatus(dynamic status) {
    if (!mounted) return;
    // PATCH STABILITAS: payload status dari plugin kadang tak terduga
    // (null / format beda saat service dibunuh sistem). Dulu throw di
    // callback event = error tak tertangkap; kini aman diabaikan.
    try {
      final s = status.state.toString().toUpperCase();
      final connecting = s.contains('CONNECTING');
      final connected =
          s.contains('CONNECTED') && !connecting && !s.contains('DISCONNECTED');
      setState(() {
        isConnecting = connecting;
        isConnected = connected;
        duration = _fmtDuration(status.duration?.toString());
        downSpeed = _parseSpeed(status.downloadSpeed?.toString());
        upSpeed = _parseSpeed(status.uploadSpeed?.toString());
        // FIX: ping tidak lagi dihapus saat VPN terputus — data tetap berguna.
      });
    } catch (_) {}
  }

  // FIX: dulu int.tryParse → selalu 0 kalau package mengirim angka terformat.
  static int _parseSpeed(String? raw) {
    if (raw == null) return 0;
    var s = raw.toUpperCase().replaceAll(',', '').trim();
    if (s.isEmpty) return 0;
    double mult = 1;
    if (s.contains('GB')) {
      mult = 1024 * 1024 * 1024;
    } else if (s.contains('MB')) {
      mult = 1024 * 1024;
    } else if (s.contains('KB')) {
      mult = 1024;
    }
    final digits = s.replaceAll(RegExp(r'[^0-9.]'), '');
    final v = double.tryParse(digits) ?? 0;
    return (v * mult).round();
  }

  static String _fmtDuration(String? raw) {
    final s = (raw ?? '').trim();
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final sec = int.tryParse(s) ?? 0;
      final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, r = sec % 60;
      final two = (int v) => v.toString().padLeft(2, '0');
      return '${two(h)}:${two(m)}:${two(r)}';
    }
    return s.isEmpty ? '00:00:00' : s;
  }

  Future<void> _init() async {
    // PATCH STABILITAS: kegagalan init inti VPN (HP tertentu / plugin)
    // tidak boleh menggagalkan pemuatan config & izin notifikasi.
    // Dulu: satu throw di sini = daftar config kosong selamanya.
    try {
      await _v2ray.initializeV2Ray();
    } catch (e) {
      debugPrint('Init inti VPN gagal (dilewati): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        savedConfigs = prefs.getStringList('vpn_configs') ?? [];
        selectedIndex = prefs.getInt('selected_index') ?? 0;
        if (selectedIndex >= savedConfigs.length) selectedIndex = 0;
        accessMode = prefs.getInt('access_mode') ?? 0;
        if (accessMode < 0 || accessMode > 2) accessMode = 0;
        accessPackages = prefs.getStringList('access_packages') ?? [];
      });

      if (!(prefs.getBool('perm_asked') ?? false)) {
        await Permission.notification.request();
        await prefs.setBool('perm_asked', true);
      }
    } catch (e) {
      debugPrint('Gagal memuat preferensi awal: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _savePrefs() async {
    // PATCH STABILITAS: kegagalan tulis disk (penuh / IO error) tidak
    // lagi menjadi exception tak tertangkap.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('vpn_configs', savedConfigs);
      await prefs.setInt('selected_index', selectedIndex);
      await prefs.setInt('access_mode', accessMode);
      await prefs.setStringList('access_packages', accessPackages);
    } catch (e) {
      debugPrint('Gagal menyimpan preferensi: $e');
    }
  }

  // Access Control → daftar blockedApps untuk plugin flutter_v2ray.
  // Mode 0 (Allow all): tidak ada yang diblokir.
  // Mode 1 (Allow selected / whitelist): blokir SEMUA yang TIDAK
  //   dipilih — plugin hanya punya blockedApps (deny list), jadi
  //   whitelist dihitung sebagai kebalikannya.
  // Mode 2 (Deny selected / blacklist): blokir yang dipilih saja.
  // Guard: mode 1 dengan pilihan KOSONG → dianggap Allow all, supaya
  //   koneksi tidak mati total karena memblokir seluruh aplikasi.
  Future<List<String>> _computeBlockedApps() async {
    if (accessMode == 0 || accessPackages.isEmpty) return const [];
    if (accessMode == 2) return List<String>.from(accessPackages);
    final all = await AppInventory.load();
    if (all.isEmpty) return const [];
    final selected = accessPackages.toSet();
    return [
      for (final a in all)
        if (!selected.contains(a.packageName)) a.packageName
    ];
  }

  void _updateAccessControl(int mode, List<String> packages) {
    setState(() {
      accessMode = mode;
      accessPackages = List<String>.from(packages);
    });
    _savePrefs();
  }

  // FIX: simpan massal dari editor kini ATOMIK. Dulu delete-all + add
  // = dua tulis SharedPreferences berlomba & pilihan melompat ke akun
  // terakhir. Kini pilihan dipertahankan berdasarkan isi akun.
  void _replaceConfigs(List<String> newConfigs) {
    setState(() {
      final oldSel = (selectedIndex >= 0 && selectedIndex < savedConfigs.length)
          ? savedConfigs[selectedIndex]
          : '';
      savedConfigs = List<String>.from(newConfigs);
      pings = {};
      if (savedConfigs.isEmpty) {
        selectedIndex = 0;
      } else {
        final match = savedConfigs.indexOf(oldSel);
        if (match >= 0) {
          selectedIndex = match;
        } else {
          int idx = selectedIndex;
          if (idx >= savedConfigs.length) idx = savedConfigs.length - 1;
          if (idx < 0) idx = 0;
          selectedIndex = idx;
        }
      }
    });
    _savePrefs();
  }

  Future<void> _deleteConfig(int index) async {
    if (index == -1) {
      // Hapus semua
      if (isConnected || isConnecting) {
        try {
          await _v2ray.stopV2Ray();
        } catch (_) {}
      }
      setState(() {
        savedConfigs = [];
        selectedIndex = 0;
        pings = {};
        isConnected = false;
        isConnecting = false;
        duration = '00:00:00';
        downSpeed = 0;
        upSpeed = 0;
      });
    } else {
      if (index < 0 || index >= savedConfigs.length) return;
      final deletingActive = index == selectedIndex;
      // FIX: hapus akun yang sedang dipakai → VPN diputus dulu
      if (deletingActive && (isConnected || isConnecting)) {
        try {
          await _v2ray.stopV2Ray();
        } catch (_) {}
      }
      setState(() {
        savedConfigs = List<String>.from(savedConfigs)..removeAt(index);
        // Geser kunci ping agar hasil tetap sejajar dengan daftar baru
        final old = Map<int, int>.from(pings);
        final shifted = <int, int>{};
        old.forEach((k, v) {
          if (k != index) shifted[k > index ? k - 1 : k] = v;
        });
        pings = shifted;
        if (selectedIndex > index) selectedIndex--;
        if (selectedIndex >= savedConfigs.length) {
          selectedIndex = savedConfigs.isEmpty ? 0 : savedConfigs.length - 1;
        }
        if (deletingActive) {
          isConnected = false;
          isConnecting = false;
          duration = '00:00:00';
          downSpeed = 0;
          upSpeed = 0;
        }
      });
    }
    _savePrefs();
  }

  Future<void> _select(int index) async {
    if (isBusy || index < 0 || index >= savedConfigs.length) return;
    if (index == selectedIndex && (isConnected || isConnecting)) return;
    setState(() => selectedIndex = index);
    _savePrefs();

    if (isConnected || isConnecting) {
      // UX: TANPA SnackBar & TANPA pindah layar. Banner di layar Proxy
      // menampilkan "Berganti akun..." secara inline dan halus, sehingga
      // pengguna tetap di daftar — tidak ada lagi jeda lompat "tab".
      setState(() {
        isBusy = true;
        isSwitching = true;
      });
      try {
        try {
          await _v2ray.stopV2Ray();
        } catch (_) {}
        // Tunggu VPN benar-benar berhenti (maks 4 detik).
        for (int i = 0;
            i < 40 && mounted && (isConnected || isConnecting);
            i++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        // PATCH STABILITAS: validasi ulang SETELAH await — daftar bisa
        // berubah selama menunggu (mis. akun dihapus dari layar lain).
        if (!mounted || index >= savedConfigs.length) return;
        final p = ConfigParser.prepare(savedConfigs[index]);
        final blocked = await _computeBlockedApps();
        if (!mounted) return;
        if (await _v2ray.requestPermission()) {
          _v2ray.startV2Ray(
            remark: p.remark,
            config: p.config,
            blockedApps: blocked,
            proxyOnly: false,
          );
        } else {
          _snack('Izin VPN ditolak.');
        }
      } catch (e) {
        _snack('Gagal berganti akun: $e');
      } finally {
        if (mounted) {
          setState(() {
            isBusy = false;
            isSwitching = false;
          });
        }
      }
    }
  }

  Future<void> _toggleConnection() async {
    // FIX: guard isConnecting → tidak bisa dobel-connect saat menyambung
    if (isBusy || isConnecting) return;
    if (isConnected) {
      setState(() {
        isBusy = true;
        isDisconnecting = true;
      });
      try {
        await _v2ray.stopV2Ray();
      } catch (_) {} finally {
        if (mounted) {
          setState(() {
            isBusy = false;
            isDisconnecting = false;
          });
        }
      }
      return;
    }
    if (savedConfigs.isEmpty) {
      _snack('Tambah profil dulu di menu Edit Config.');
      return;
    }
    setState(() => isBusy = true);
    try {
      // FIX: int.clamp() mengembalikan num → tidak bisa dipakai sebagai
      // index list (error compile di versi lama). Kini penjajaran manual.
      int idx = selectedIndex;
      if (idx >= savedConfigs.length) idx = savedConfigs.length - 1;
      if (idx < 0) idx = 0;
      if (idx != selectedIndex) {
        setState(() => selectedIndex = idx);
      }
      final p = ConfigParser.prepare(savedConfigs[idx]);
      final blocked = await _computeBlockedApps();
      if (!mounted) return; // PATCH STABILITAS: guard setelah await
      if (await _v2ray.requestPermission()) {
        _v2ray.startV2Ray(
          remark: p.remark,
          config: p.config,
          blockedApps: blocked,
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

  // FIX: ping kini jalan kapan pun (dulu loop langsung batal kalau VPN
  // belum terhubung), hasil tersimpan di peta pings, dan muncul info
  // kalau semua server gagal.
  Future<void> _measurePings() async {
    if (isRefreshingPing) return;
    if (savedConfigs.isEmpty) {
      _snack('Belum ada profil untuk di-ping.');
      return;
    }
    // PATCH STABILITAS: iterasi memakai SNAPSHOT daftar — daftar asli
    // bisa berubah (hapus/simpan editor) di tengah pengukuran sehingga
    // index tidak melenceng.
    final snapshot = List<String>.from(savedConfigs);
    setState(() {
      isRefreshingPing = true;
      pings = {};
    });

    int ok = 0;
    try {
      for (int i = 0; i < snapshot.length; i++) {
        if (!mounted) return;
        try {
          final p = ConfigParser.prepare(snapshot[i]);
          final d = await _v2ray
              .getServerDelay(config: p.config)
              .timeout(const Duration(seconds: 8));
          if (!mounted) return;
          if (d >= 0) ok++;
          setState(() => pings[i] = (d >= 0) ? d : -1);
        } catch (_) {
          if (!mounted) return;
          setState(() => pings[i] = -1);
        }
      }
    } finally {
      // PATCH STABILITAS: isRefreshingPing DIJAMIN reset — dulu bisa
      // stuck true bila error di luar dugaan → FAB ping mati selamanya.
      if (mounted) {
        setState(() => isRefreshingPing = false);
      }
    }
    if (!mounted) return;
    if (ok == 0) _snack('Semua server gagal di-ping. Cek koneksi internet.');
  }

  String get _selectedName {
    if (savedConfigs.isEmpty || selectedIndex >= savedConfigs.length) return '';
    try {
      return ConfigParser.describe(savedConfigs[selectedIndex]).name;
    } catch (_) {
      return '';
    }
  }

  void _goToConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // FIX: data dikirim lewat getter + Listenable → layar Proxy live
        builder: (context) => ProfileScreen(
          data: () => ProxyScreenData(
            configs: savedConfigs,
            selectedIndex: selectedIndex,
            isConnected: isConnected,
            isConnecting: isConnecting,
            isBusy: isBusy,
            isDisconnecting: isDisconnecting,
            isSwitching: isSwitching,
            isRefreshingPing: isRefreshingPing,
            duration: duration,
            pings: Map<int, int>.from(pings),
          ),
          listenable: _proxyListeners,
          onSelect: _select,
          onToggle: _toggleConnection,
          onRefreshPing: _measurePings,
          onDelete: _deleteConfig,
          onReplace: _replaceConfigs,
        ),
      ),
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
          accessMode: accessMode,
          accessPackages: List<String>.from(accessPackages),
          onAccessChanged: _updateAccessControl,
        ),
      ),
    );
  }

  void _goToAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Xailla Class',
      applicationVersion: appVersion,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/logo.png',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          // FIX: fallback ikon bila aset logo hilang (dulu bisa crash)
          errorBuilder: (_, __, ___) => const Icon(Icons.vpn_key_rounded, size: 32),
        ),
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
      isConnecting: isConnecting,
      isBusy: isBusy,
      duration: duration,
      downSpeed: downSpeed,
      upSpeed: upSpeed,
      selectedName: _selectedName,
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
  final bool isConnecting;
  final bool isBusy;
  final String duration;
  final String selectedName;
  final int downSpeed;
  final int upSpeed;
  final VoidCallback onToggle;
  final VoidCallback onOpenConfig;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.isBusy,
    required this.duration,
    required this.selectedName,
    required this.downSpeed,
    required this.upSpeed,
    required this.onToggle,
    required this.onOpenConfig,
    required this.onOpenSettings,
    required this.onOpenAbout,
  });

  // FIX: dulu (bytes/1024) apa adanya → kecepatan MB tampil "ribuan KB".
  String _fmtSpeed(int bytes) {
    if (bytes <= 0) return '0 KB/s';
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final bool working = isBusy || isConnecting;
    final String statusText;
    if (working) {
      statusText = isConnected ? 'Memutuskan...' : 'Menghubungkan...';
    } else {
      statusText = isConnected ? 'Connected' : 'Disconnected';
    }
    final Color connectColor = isConnected
        ? Colors.green.shade600
        : (working
            ? Colors.orange.shade700
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade400));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // LOGO BOXFIT CONTAIN (ANTI BAYANGAN) — dipertahankan
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      // FIX: fallback ikon bila aset hilang (dulu red error)
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.vpn_key_rounded,
                        size: 40,
                        color: Color(0xFF7B1FA2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'XAILLA CLASS',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              GestureDetector(
                // FIX: tap diabaikan saat sedang menyambung/memutus
                onTap: working ? null : onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: connectColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: connectColor.withOpacity(0.25),
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
                              statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConnected
                                  ? '↓ ${_fmtSpeed(downSpeed)}   ↑ ${_fmtSpeed(upSpeed)}   |   $duration'
                                  : (working ? 'Mempersiapkan koneksi...' : 'Tap to connect'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // FIX: tampilkan akun yang sedang dipakai
                            if (isConnected && selectedName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'via $selectedName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (working)
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
        // v2.1.0: menu diringkas — dulu terlalu besar (ikon 28, judul 18,
        // padding 16). Kini padat seperti menu aplikasi referensi.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isTransparent ? Colors.transparent : cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isTransparent
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ======================= PROFIL SCREEN =======================

class ProfileScreen extends StatefulWidget {
  final ProxyScreenData Function() data;
  final Listenable listenable;
  final void Function(int) onSelect;
  final VoidCallback onToggle;
  final VoidCallback onRefreshPing;
  final Future<void> Function(int) onDelete;
  final void Function(List<String>) onReplace;

  const ProfileScreen({
    super.key,
    required this.data,
    required this.listenable,
    required this.onSelect,
    required this.onToggle,
    required this.onRefreshPing,
    required this.onDelete,
    required this.onReplace,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Tab sortir aktif. v2.0.4: dipulihkan dari SharedPreferences agar
  // tetap di tab terakhir walaupun layar Proxy ditutup lalu dibuka
  // lagi dari Home (dulu selalu lompat balik ke "Select" karena layar
  // ini adalah route yang dibuat ulang setiap kali dibuka).
  int _activeTab = 0;
  // Guard: bila pengguna sudah menekan tab sebelum proses restore
  // selesai, hasil restore TIDAK boleh menimpa pilihan pengguna.
  bool _tabTouched = false;

  // UX: mode layar bersifat "sticky" — TIDAK lagi otomatis mengikuti
  // status VPN. Dulu: begitu VPN berhenti (mis. saat ganti akun),
  // layar melompat ke Config Editor lalu kembali lagi ke daftar →
  // terasa seperti pindah "tab" yang mengganggu. Kini: sekali di
  // daftar Proxy, tetap di sini sampai pengguna sendiri menekan ikon
  // edit (ke editor) atau back (ke Home).
  bool _showListView = false;
  bool _editorFromList = false;

  // FIX: tiap tab kini punya fungsi sortir yang benar-benar BERBEDA
  // (dulu Best Ping & Fallback sama persis, Load Balance = urut nama
  // tanpa keterangan apa pun).
  static const List<String> _tabLabels = ['Select', 'Best Ping', 'Fallback', 'Load Balance'];
  static const List<String> _tabCaptions = [
    'Urutan manual — pilih akun sesukamu.',
    'Ping tercepat ditampilkan paling atas.',
    'Server timeout / bermasalah ditampilkan lebih dulu.',
    'Diurutkan berdasarkan nama (A-Z).',
  ];

  List<TextEditingController> _controllers = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initConfigs();
    // Mode awal: daftar Proxy bila VPN sedang aktif/menyambung/beralih,
    // editor bila idle — sama seperti desain lama, tapi mode ini TIDAK
    // berubah sendiri setelah layar terbuka.
    final d0 = widget.data();
    _showListView = d0.isConnected || d0.isConnecting || d0.isBusy;
    _restoreTab();
  }

  // FIX (v2.0.4): tab sortir selalu kembali ke "Select" karena layar
  // Proxy adalah route yang dibuat ulang setiap dibuka dari Home.
  // Kini tab terakhir tersimpan permanen dan HANYA berubah bila
  // pengguna sendiri menekan tab lain.
  Future<void> _restoreTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('proxy_tab') ?? 0;
      if (saved < 0 || saved >= _tabLabels.length) return;
      if (!mounted || _tabTouched || _activeTab == saved) return;
      setState(() => _activeTab = saved);
    } catch (_) {}
  }

  Future<void> _persistTab(int i) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('proxy_tab', i);
    } catch (_) {}
  }

  void _setTab(int i) {
    _tabTouched = true;
    if (_activeTab == i) return;
    setState(() => _activeTab = i);
    _persistTab(i);
  }

  void _initConfigs() {
    if (_isInitialized) return;
    _controllers = [];

    final configs = widget.data().configs;
    if (configs.isNotEmpty) {
      for (var config in configs) {
        _controllers.add(TextEditingController(text: ConfigParser.toYaml(config)));
      }
    } else {
      _controllers.add(TextEditingController());
    }
    _isInitialized = true;
  }

  // Bangun ulang buffer editor dari config tersimpan (dipakai setelah
  // simpan saat editor dibuka dari daftar Proxy).
  void _rebuildControllersFromData() {
    final old = List<TextEditingController>.from(_controllers);
    final configs = widget.data().configs;
    _controllers = configs.isNotEmpty
        ? [
            for (final c in configs)
              TextEditingController(text: ConfigParser.toYaml(c)),
          ]
        : <TextEditingController>[TextEditingController()];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  // ---- Pindah mode manual: daftar Proxy <-> Config Editor ----
  void _openEditor() {
    setState(() {
      _editorFromList = true;
      _showListView = false;
    });
  }

  void _closeEditor() {
    if (_editorFromList) {
      // Dibuka dari daftar Proxy → kembali ke daftar, bukan ke Home.
      setState(() {
        _showListView = true;
        _editorFromList = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // FIX: clipboard YAML/JSON kini ikut terdeteksi (dulu hanya link://)
  Future<void> _addNewField() async {
    String initialText = '';
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';
      final lower = text.toLowerCase();
      if (lower.startsWith('vmess://') ||
          lower.startsWith('vless://') ||
          lower.startsWith('trojan://') ||
          lower.startsWith('ss://')) {
        try {
          initialText = ConfigParser.toYaml(text);
        } catch (_) {
          initialText = text;
        }
      } else if (ConfigParser.isYaml(text) || text.startsWith('{')) {
        initialText = text;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _controllers.add(TextEditingController(text: initialText)));
  }

  String? _validateBlock(String block) {
    try {
      if (block.startsWith('{')) {
        jsonDecode(block);
        return null;
      }
      if (ConfigParser.isYaml(block)) {
        final f = ConfigParser.getFields(block);
        if ((f['server'] ?? '').isEmpty) return 'Server kosong pada salah satu akun';
        if ((f['type'] ?? '').isEmpty) return 'Tipe (trojan/vmess/vless/ss) kosong pada salah satu akun';
        return null;
      }
      final lower = block.toLowerCase();
      if (lower.startsWith('vmess://')) {
        try {
          final m =
              jsonDecode(utf8.decode(ConfigParser.b64decode(block.substring(8)))) as Map<String, dynamic>;
          if ((m['add'] ?? '').toString().isEmpty) return 'Link vmess: alamat server (add) kosong';
        } catch (_) {
          return 'Link vmess rusak (bukan base64/JSON valid)';
        }
        return null;
      }
      final uri = Uri.tryParse(block);
      if (uri == null) return 'Format link tidak dikenali';
      switch (uri.scheme.toLowerCase()) {
        case 'vless':
        case 'trojan':
          if (uri.userInfo.isEmpty) return 'Link ${uri.scheme} tidak memiliki UUID/password';
          if (uri.host.isEmpty) return 'Server kosong pada link ${uri.scheme}';
          return null;
        case 'ss':
          return ConfigParser.parseSS(block) == null
              ? 'Link ss tidak valid / tidak dapat dibaca'
              : null;
        default:
          return 'Format link tidak dikenali (${uri.scheme}://)';
      }
    } catch (e) {
      return 'Format tidak valid: ${e.toString().replaceAll('Exception: ', '')}';
    }
  }

  void _saveConfigs() {
    final validConfigs = <String>[];
    final accountNames = <String>[];
    final errors = <String>[];

    for (int i = 0; i < _controllers.length; i++) {
      final rawText = _controllers[i].text.trim();
      if (rawText.isEmpty) continue;

      final blocks = rawText.split('---').map((e) => e.trim()).where((e) => e.isNotEmpty);

      for (var block in blocks) {
        final err = _validateBlock(block);
        if (err != null) {
          errors.add(err);
          continue;
        }
        final info = ConfigParser.describe(block);
        if (accountNames.contains(info.name)) {
          errors.add('Akun "${info.name}" ganda. Ganti nama salah satunya.');
          continue;
        }
        accountNames.add(info.name);
        validConfigs.add(block);
      }
    }

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gagal Menyimpan'),
          content: SingleChildScrollView(child: Text(errors.join('\n\n'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Perbaiki')),
          ],
        ),
      );
      return;
    }

    if (validConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config tidak boleh kosong')),
      );
      return;
    }

    // FIX: satu operasi atomik (dulu delete-all + add berlomba menulis
    // prefs & pilihan melompat ke akun terakhir)
    widget.onReplace(validConfigs);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Config berhasil disimpan')),
    );
    if (_editorFromList) {
      // Kembali ke daftar Proxy (bukan keluar ke Home) & sinkronkan
      // buffer editor dengan hasil simpanan terbaru.
      _rebuildControllersFromData();
      setState(() {
        _showListView = true;
        _editorFromList = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  // Hapus dari buffer EDITOR (permanen setelah tombol save ditekan)
  void _showMenu(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus Akun Ini'),
              onTap: () {
                Navigator.pop(ctx);
                if (index < 0 || index >= _controllers.length) return;
                // FIX: dispose dilakukan setelah frame agar tidak crash
                final removed = _controllers.removeAt(index);
                if (_controllers.isEmpty) _controllers.add(TextEditingController());
                setState(() {});
                WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
              },
            ),
          ],
        ),
      ),
    );
  }

  // FIX: hapus di mode LIST kini menghapus akun SUNGGUHAN + konfirmasi.
  // Dulu hanya menghapus buffer editor — akun muncul lagi setelah disimpan.
  void _confirmDeleteAccount(BuildContext context, int index, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Hapus "$name" secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return; // PATCH STABILITAS
              // sinkronkan buffer editor agar tidak "hidup lagi" saat disimpan
              if (index < _controllers.length) {
                final removed = _controllers.removeAt(index);
                WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
              }
              widget.onDelete(index);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<MapEntry<int, String>> _getDisplayedConfigs(ProxyScreenData d) {
    final list = d.configs.asMap().entries.toList();

    int pingOf(int key) {
      final p = d.pings[key];
      if (p == null) return 99999; // belum di-ping → paling bawah
      return p < 0 ? 100000 : p; // timeout → di bawah yang belum di-ping
    }

    if (_activeTab == 1) {
      // Best Ping: tercepat dulu
      list.sort((a, b) {
        final r = pingOf(a.key) - pingOf(b.key);
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    } else if (_activeTab == 2) {
      // Fallback: yang bermasalah dulu, sisanya ping tercepat dulu
      list.sort((a, b) {
        final failA = (d.pings[a.key] ?? 1) == -1 ? 0 : 1;
        final failB = (d.pings[b.key] ?? 1) == -1 ? 0 : 1;
        if (failA != failB) return failA - failB;
        final r = pingOf(a.key) - pingOf(b.key);
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    } else if (_activeTab == 3) {
      // Load Balance: urut nama A-Z
      // PATCH STABILITAS/PERF: nama dihitung SEKALI di awal — dulu
      // describe() (parsing link) dipanggil 2x per perbandingan sehingga
      // daftar panjang bikin jank/frame lewat.
      final names = <int, String>{
        for (final e in list)
          e.key: ConfigParser.describe(e.value).name.toLowerCase(),
      };
      list.sort((a, b) {
        final r = names[a.key]!.compareTo(names[b.key]!);
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.listenable,
      builder: (context, _) {
        final d = widget.data();
        return _buildScreen(context, d);
      },
    );
  }

  Widget _buildScreen(BuildContext context, ProxyScreenData d) {
    // Mode layar kini STICKY — tidak lagi berganti otomatis mengikuti
    // status VPN. Dulu: begitu VPN berhenti saat ganti akun, layar
    // melompat ke editor lalu balik lagi ke daftar (terasa seperti
    // pindah "tab"). Kini transisi antar-mode pakai fade halus dan
    // hanya bergerak kalau pengguna yang memutuskan.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<bool>(_showListView),
        child: _showListView
            ? _buildProxyList(context, d)
            : _buildEditor(context),
      ),
    );
  }

  // ------------------------- MODE EDITOR -------------------------

  Widget _buildEditor(BuildContext context) {
    // FIX: warna kini mengikuti tema (dulu hardcode putih → dark mode rusak)
    final cs = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: cs.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeEditor,
        ),
        title: Text(
          'Config Editor',
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addNewField),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveConfigs),
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
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: cs.onSurface,
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

  // ------------------------ MODE LIST PROXY ------------------------

  Widget _buildProxyList(BuildContext context, ProxyScreenData d) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final displayed = _getDisplayedConfigs(d);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: cs.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Proxy',
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Config',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEditor,
          ),
        ],
      ),
      body: Column(
        children: [
          // UX: banner "VPN Aktif" sengaja DIHAPUS agar tampilan bersih —
          // status & tombol memutus cukup dari layar Home. Umpan balik
          // saat ganti akun tampil sebagai spinner kecil di kartu akun.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabLabels.length, (i) => _tabButton(context, i, isDark)),
              ),
            ),
          ),
          // FIX: keterangan fungsi tab yang sedang aktif
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_tabCaptions[_activeTab], style: TextStyle(fontSize: 11, color: cs.outline)),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: d.configs.isEmpty
                ? const Center(
                    child: Text('Belum ada profil. Tekan + di Config Editor untuk menambah.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayed.length,
                    itemBuilder: (context, i) {
                      final entry = displayed[i];
                      final index = entry.key;
                      final configString = entry.value;

                      final desc = ConfigParser.describe(configString);
                      final isSelected = index == d.selectedIndex;
                      final ping = d.pings[index];

                      return Card(
                        elevation: 0,
                        color: isSelected
                            ? Colors.purple.shade900
                            : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Icon(
                            desc.type == 'vmess'
                                ? Icons.cloud
                                : (desc.type == 'ss' ? Icons.enhanced_encryption : Icons.security),
                            color: isSelected ? Colors.white : Colors.purple,
                          ),
                          title: Text(
                            desc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : cs.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            desc.type.toUpperCase(),
                            style: TextStyle(color: isSelected ? Colors.white70 : cs.outline),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // FIX: ping kini chip berwarna dengan satuan ms
                              _pingChip(ping, isSelected),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  // Umpan balik halus saat menyambungkan /
                                  // berganti akun: spinner kecil menggantikan
                                  // centang di kartu akun yang dipilih.
                                  child: (d.isSwitching || d.isConnecting)
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                )
                              else
                                const SizedBox(width: 28),
                            ],
                          ),
                          onTap: () => widget.onSelect(index),
                          onLongPress: () => _confirmDeleteAccount(context, index, desc.name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple.shade900,
        tooltip: 'Test ping semua server',
        onPressed: d.isRefreshingPing ? null : widget.onRefreshPing,
        child: d.isRefreshingPing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.bolt, color: Colors.white),
      ),
    );
  }

  Widget _pingChip(int? ping, bool selected) {
    Color c;
    String t;
    if (ping == null) {
      c = Colors.grey;
      t = '—';
    } else if (ping < 0) {
      c = Colors.red;
      t = 'Timeout';
    } else {
      c = ping < 150 ? Colors.green : (ping < 300 ? Colors.orange : Colors.red);
      t = '$ping ms';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.white24 : c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: selected ? Colors.white : c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, int tabIndex, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final isActive = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () => _setTab(tabIndex),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.purple.shade900 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.15)),
        ),
        child: Text(
          _tabLabels[tabIndex],
          style: TextStyle(
            color: isActive ? Colors.white : cs.outline,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ======================= SETTINGS =======================

// v2.2.0: layar Settings disamakan dengan foto referensi:
// - Judul "App", section "Interface" & "VpnService Options"
// - Dark Mode: dropdown popup (opsi terpilih berlatar ungu)
// - Root Tethering: nonaktif (butuh root)
// - Access Control Mode: dropdown popup (Allow all / Allow selected / Deny selected)
// - Access Control Packages: halaman daftar aplikasi
class SettingsScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final Function(ThemeMode) onThemeChanged;
  final int accessMode; // 0=Allow all, 1=Allow selected, 2=Deny selected
  final List<String> accessPackages;
  final void Function(int mode, List<String> packages) onAccessChanged;
  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
    required this.accessMode,
    required this.accessPackages,
    required this.onAccessChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _mode = widget.currentMode;
  late int _accessMode = widget.accessMode;
  late List<String> _packages = List<String>.from(widget.accessPackages);

  final GlobalKey _themeKey = GlobalKey();
  final GlobalKey _accessKey = GlobalKey();

  static const Map<ThemeMode, String> _themeLabels = {
    ThemeMode.system: 'Follow System (Android 10+)',
    ThemeMode.light: 'Always Light',
    ThemeMode.dark: 'Always Dark',
  };
  static const List<String> _accessLabels = [
    'Allow all apps',
    'Allow selected apps',
    'Deny selected apps',
  ];

  // Posisi teks pada baris (ikon 32 + padding kiri 16 + jarak 16).
  static const double _textLeft = 64;

  void _pickTheme(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.onThemeChanged(mode);
  }

  void _pickAccessMode(int mode) {
    setState(() => _accessMode = mode);
    widget.onAccessChanged(mode, _packages);
  }

  Future<void> _openPackages() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccessControlScreen(
          selected: List<String>.from(_packages),
          onChanged: (pkgs) {
            if (!mounted) return;
            setState(() => _packages = List<String>.from(pkgs));
            widget.onAccessChanged(_accessMode, _packages);
          },
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return; // PATCH STABILITAS
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // Dropdown popup seperti foto: muncul tepat di bawah baris, sejajar
  // dengan teks, opsi terpilih berlatar ungu + teks putih.
  Future<void> _showDropdown({
    required GlobalKey anchor,
    required List<String> labels,
    required int selectedIndex,
    required void Function(int) onPick,
  }) async {
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    double left = origin.dx + _textLeft;
    double top = origin.dy + box.size.height - 6;
    // PATCH STABILITAS: posisi dijepit ke dalam overlay — nilai negatif
    // / melebihi layar bisa memicu assertion "outside of overlay".
    if (left < 0) left = 0;
    if (left > overlay.size.width) left = overlay.size.width;
    if (top < 0) top = 0;
    if (top > overlay.size.height) top = overlay.size.height;
    final position = RelativeRect.fromLTRB(
      left,
      top,
      overlay.size.width - left,
      overlay.size.height - top,
    );

    const style = TextStyle(fontSize: 14.5);
    double textW = 0;
    for (final l in labels) {
      final tp = TextPainter(
        text: TextSpan(text: l, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > textW) textW = tp.width;
    }
    // Menu popup selalu dibulatkan ke kelipatan 56dp → samakan lebar item
    // agar latar ungu terpilih memenuhi lebar menu (tanpa celah putih).
    double w = ((textW + 40) / 56).ceil() * 56.0;
    if (w < 168) w = 168;
    if (w > 280) w = 280;

    final result = await showMenu<int>(
      context: context,
      position: position,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: [
        for (int i = 0; i < labels.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 48,
            padding: EdgeInsets.zero,
            child: Container(
              width: w,
              height: 48,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: i == selectedIndex ? Colors.purple.shade700 : null,
              child: Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  color: i == selectedIndex ? Colors.white : null,
                ),
              ),
            ),
          ),
      ],
    );
    if (result != null && mounted) onPick(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _section(context, 'Interface'),
          _row(
            context,
            key: _themeKey,
            icon: Icons.brightness_medium,
            title: 'Dark Mode',
            subtitle: _themeLabels[_mode],
            onTap: () => _showDropdown(
              anchor: _themeKey,
              labels: _themeLabels.values.toList(),
              selectedIndex: ThemeMode.values.indexOf(_mode),
              onPick: (i) => _pickTheme(ThemeMode.values[i]),
            ),
          ),
          _section(context, 'VpnService Options'),
          _row(
            context,
            title: 'Root Tethering',
            disabled: true,
            trailing: const Switch(value: false, onChanged: null),
            onTap: () => _snack('Root Tethering butuh akses root — tidak tersedia.'),
          ),
          _row(
            context,
            key: _accessKey,
            title: 'Access Control Mode',
            subtitle: _accessLabels[_accessMode],
            onTap: () => _showDropdown(
              anchor: _accessKey,
              labels: _accessLabels,
              selectedIndex: _accessMode,
              onPick: _pickAccessMode,
            ),
          ),
          _row(
            context,
            title: 'Access Control Packages',
            subtitle: _packages.isEmpty
                ? 'Configure access permission for apps'
                : 'Configure access permission for apps (${_packages.length})',
            onTap: _openPackages,
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }

  // Baris tanpa ikon tetap menyisakan ruang ikon agar teks sejajar (foto).
  Widget _row(
    BuildContext context, {
    Key? key,
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool disabled = false,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final titleColor = disabled ? cs.onSurface.withOpacity(0.38) : cs.onSurface;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: icon == null
                  ? null
                  : Icon(icon, size: 24, color: cs.onSurface),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

// ======================= ACCESS CONTROL PACKAGES =======================

// v2.2.0 — halaman pemilihan aplikasi (sesuai foto referensi):
// AppBar berisi ikon Search + menu titik tiga. Menu: Select All / Select
// None / Select Invert, lalu submenu Filter (System Apps), Sort (Name /
// Package Name / Install Time / Update Time + Reverse) dan External
// (Import / Export Clipboard). Daftar menampilkan ikon aplikasi, nama,
// package, dan kotak centang. Setiap perubahan langsung tersimpan.
class AccessControlScreen extends StatefulWidget {
  final List<String> selected;
  final void Function(List<String> packages) onChanged;
  const AccessControlScreen({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  static const List<String> _sortLabels = [
    'Name',
    'Package Name',
    'Install Time',
    'Update Time',
  ];

  List<VpnAppInfo> _apps = [];
  bool _loading = true;
  final Set<String> _selected = {};
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';
  bool _showSystem = true;
  int _sortBy = 0; // 0=Name, 1=Package Name, 2=Install Time, 3=Update Time
  bool _reverse = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.selected);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps = await AppInventory.load(withIcons: true);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  void _commit() => widget.onChanged(_selected.toList());

  void _toggle(String pkg) {
    setState(() {
      if (_selected.contains(pkg)) {
        _selected.remove(pkg);
      } else {
        _selected.add(pkg);
      }
    });
    _commit();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  int _compare(VpnAppInfo a, VpnAppInfo b) {
    int r;
    switch (_sortBy) {
      case 1:
        r = a.packageName.toLowerCase().compareTo(b.packageName.toLowerCase());
        break;
      case 2:
        r = a.installTime.compareTo(b.installTime);
        break;
      case 3:
        r = a.updateTime.compareTo(b.updateTime);
        break;
      default:
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    return _reverse ? -r : r;
  }

  List<VpnAppInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = _apps.where((a) {
      if (!_showSystem && a.systemApp) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.packageName.toLowerCase().contains(q);
    }).toList();
    list.sort(_compare);
    return list;
  }

  // ---------------- Menu titik tiga (utama + submenu) ----------------

  Future<void> _openMenu([String page = 'main']) async {
    final mq = MediaQuery.of(context);
    final position = RelativeRect.fromLTRB(
      mq.size.width,
      mq.padding.top + kToolbarHeight,
      0,
      0,
    );

    final List<PopupMenuEntry<String>> items;
    switch (page) {
      case 'filter':
        items = [
          _mi('menu', 'Filter', bold: true),
          _mi('toggle:system', 'System Apps',
              trailing: _checkIcon(_showSystem)),
        ];
        break;
      case 'sort':
        items = [
          _mi('menu', 'Sort', bold: true),
          for (int i = 0; i < _sortLabels.length; i++)
            _mi('sort:$i', _sortLabels[i], trailing: _radioIcon(_sortBy == i)),
          _mi('reverse', 'Reverse', trailing: _checkIcon(_reverse)),
        ];
        break;
      case 'external':
        items = [
          _mi('menu', 'External', bold: true),
          _mi('import', 'Import from Clipboard'),
          _mi('export', 'Export to Clipboard'),
        ];
        break;
      default:
        items = [
          _mi('all', 'Select All'),
          _mi('none', 'Select None'),
          _mi('invert', 'Select Invert'),
          _mi('page:filter', 'Filter', trailing: _arrow()),
          _mi('page:sort', 'Sort', trailing: _arrow()),
          _mi('page:external', 'External', trailing: _arrow()),
        ];
    }

    final v = await showMenu<String>(
      context: context,
      position: position,
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 280),
      items: items,
    );
    if (v == null || !mounted) return;
    _onMenu(v);
  }

  void _onMenu(String value) {
    if (value == 'menu') {
      _openMenu('main');
    } else if (value.startsWith('page:')) {
      _openMenu(value.substring(5));
    } else if (value == 'all') {
      setState(() {
        for (final a in _filtered) {
          _selected.add(a.packageName);
        }
      });
      _commit();
    } else if (value == 'none') {
      setState(_selected.clear);
      _commit();
    } else if (value == 'invert') {
      setState(() {
        for (final a in _filtered) {
          if (_selected.contains(a.packageName)) {
            _selected.remove(a.packageName);
          } else {
            _selected.add(a.packageName);
          }
        }
      });
      _commit();
    } else if (value == 'toggle:system') {
      setState(() => _showSystem = !_showSystem);
    } else if (value == 'reverse') {
      setState(() => _reverse = !_reverse);
    } else if (value.startsWith('sort:')) {
      setState(() => _sortBy = int.tryParse(value.substring(5)) ?? 0);
    } else if (value == 'import') {
      _importFromClipboard();
    } else if (value == 'export') {
      _exportToClipboard();
    }
  }

  // Terima daftar package dari clipboard: JSON array atau per baris.
  // Hanya package yang benar-benar terpasang yang diterima.
  Future<void> _importFromClipboard() async {
    // PATCH STABILITAS: baca clipboard dibungkus try/catch (beberapa
    // ROM membatasi akses clipboard), plus guard mounted setelah await.
    String text = '';
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = (data?.text ?? '').trim();
    } catch (_) {
      _snack('Gagal membaca clipboard.');
      return;
    }
    if (text.isEmpty) {
      _snack('Clipboard kosong.');
      return;
    }
    List<String> pkgs = [];
    if (text.startsWith('[')) {
      try {
        final v = json.decode(text);
        if (v is List) {
          pkgs = v
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    if (pkgs.isEmpty) {
      pkgs = text
          .split(RegExp(r'[\s,;]+'))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final known = _apps.map((a) => a.packageName).toSet();
    final valid = pkgs.where(known.contains).toSet();
    if (valid.isEmpty) {
      _snack('Tidak ada package yang dikenali di clipboard.');
      return;
    }
    if (!mounted) return; // PATCH STABILITAS: guard setelah await
    setState(() => _selected.addAll(valid));
    _commit();
    _snack('${valid.length} package diimpor dari clipboard.');
  }

  Future<void> _exportToClipboard() async {
    if (_selected.isEmpty) {
      _snack('Belum ada package yang dipilih.');
      return;
    }
    // PATCH STABILITAS: tulis clipboard juga bisa gagal (ROM terbatas).
    try {
      await Clipboard.setData(
          ClipboardData(text: _selected.toList().join('\n')));
      _snack('${_selected.length} package diekspor ke clipboard.');
    } catch (_) {
      _snack('Gagal menyalin ke clipboard.');
    }
  }

  // ---------------- Widget bantu menu ----------------

  PopupMenuItem<String> _mi(
    String value,
    String label, {
    Widget? trailing,
    bool bold = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _arrow() => Icon(Icons.arrow_right, size: 24, color: Colors.grey.shade600);

  Widget _checkIcon(bool on) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      on ? Icons.check_box : Icons.check_box_outline_blank,
      size: 22,
      color: on ? cs.primary : cs.outline,
    );
  }

  Widget _radioIcon(bool on) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      size: 22,
      color: on ? cs.primary : cs.outline,
    );
  }

  Widget _appIcon(VpnAppInfo app) {
    final bytes = app.icon;
    return SizedBox(
      width: 40,
      height: 40,
      child: bytes != null && bytes.isNotEmpty
          ? Image.memory(
              bytes,
              gaplessPlayback: true,
              cacheWidth: 96,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.android, color: Colors.green),
            )
          : const Icon(Icons.android, color: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _filtered;
    return PopScope(
      canPop: !_searching,
      onPopInvoked: (didPop) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _searching ? _closeSearch : () => Navigator.pop(context),
          ),
          title: _searching
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                  ),
                )
              : const Text(
                  'Access Control Packages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            if (_searching)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (_searchCtrl.text.isEmpty) {
                    _closeSearch();
                  } else {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  }
                },
              )
            else
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
              ),
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.more_vert),
              onPressed: _openMenu,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _apps.isEmpty
                                ? 'Tidak bisa memuat daftar aplikasi.\n'
                                    'Cek AndroidManifest (QUERY_ALL_PACKAGES).'
                                : 'Tidak ada aplikasi yang cocok.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                          if (_apps.isEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (ctx, i) {
                      final app = visible[i];
                      final checked = _selected.contains(app.packageName);
                      return ListTile(
                        visualDensity: const VisualDensity(vertical: -1),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        onTap: () => _toggle(app.packageName),
                        leading: _appIcon(app),
                        title: Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5),
                        ),
                        subtitle: Text(
                          app.packageName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: Checkbox(
                          value: checked,
                          onChanged: (_) => _toggle(app.packageName),
                        ),
                      );
                    },
                  )),
      ),
    );
  }
}