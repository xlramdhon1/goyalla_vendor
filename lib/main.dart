import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VendorDashboard(),
    );
  }
}

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  final CookieManager _cookieManager = CookieManager.instance();
  InAppWebViewController? _webViewController;
  late final PullToRefreshController _pullToRefreshController;

  String initialUrl = "https://goyalla.id/login?redirect=/user/dashboard";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(color: Colors.blue),
      onRefresh: () async {
        // NOTE: canReload() tidak tersedia -> langsung reload()
        if (_webViewController != null) {
          try {
            await _webViewController!.reload();
          } catch (e) {
            // kalau gagal, hentikan animasi refresh agar tidak macet
            _pullToRefreshController.endRefreshing();
          }
        } else {
          _pullToRefreshController.endRefreshing();
        }
      },
    );

    // restore cookies sebelum WebView load
    _restoreCookies();
  }

  Future<void> _restoreCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCookies = prefs.getStringList("vendor_cookies") ?? [];

    for (var c in savedCookies) {
      final parts = c.split(";");
      if (parts.length >= 2) {
        await _cookieManager.setCookie(
          url: WebUri("https://goyalla.id"),
          name: parts[0],
          value: parts[1],
        );
      }
    }
  }

  Future<void> _saveCookies() async {
    final cookies = await _cookieManager.getCookies(
      url: WebUri("https://goyalla.id"),
    );
    final prefs = await SharedPreferences.getInstance();
    final cookieStrings = cookies.map((c) => "${c.name};${c.value}").toList();
    await prefs.setStringList("vendor_cookies", cookieStrings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                clearCache: false,
                cacheEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
              ),
              pullToRefreshController: _pullToRefreshController,
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStop: (controller, url) async {
                // simpan cookie & hentikan animasi refresh
                await _saveCookies();
                _pullToRefreshController.endRefreshing();
                setState(() => isLoading = false);
              },
              onLoadError: (controller, url, code, message) {
                _pullToRefreshController.endRefreshing();
                setState(() => isLoading = false);
              },
              onLoadHttpError: (controller, url, statusCode, description) {
                _pullToRefreshController.endRefreshing();
                setState(() => isLoading = false);
              },
            ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
