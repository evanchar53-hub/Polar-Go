import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const PolarGoApp());

/// Polar Suite Brand Palette: Royal Blue, Powder Blue, Silver, and White
class PolarColors {
  static const Color royalBlue = Color(0xFF1E40AF);
  static const Color deepRoyal = Color(0xFF172554);
  static const Color powderBlue = Color(0xFFB0E0E6);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color iceSurface = Color(0xFFF4F9FC);
}

class SearchEngine {
  final String id;
  final String name;
  final String queryPrefix;

  const SearchEngine({
    required this.id,
    required this.name,
    required this.queryPrefix,
  });
}

const List<SearchEngine> kSearchEngines = [
  SearchEngine(
    id: 'ddg',
    name: 'DuckDuckGo',
    queryPrefix: 'https://duckduckgo.com/?q=',
  ),
  SearchEngine(
    id: 'google',
    name: 'Google',
    queryPrefix: 'https://www.google.com/search?q=',
  ),
  SearchEngine(
    id: 'brave',
    name: 'Brave Search',
    queryPrefix: 'https://search.brave.com/search?q=',
  ),
  SearchEngine(
    id: 'ecosia',
    name: 'Ecosia',
    queryPrefix: 'https://www.ecosia.org/search?q=',
  ),
];

class SpeedDialItem {
  final String title;
  final String url;
  final IconData icon;

  const SpeedDialItem({
    required this.title,
    required this.url,
    required this.icon,
  });
}

const List<SpeedDialItem> kSpeedDial = [
  SpeedDialItem(
    title: 'DuckDuckGo',
    url: 'https://duckduckgo.com',
    icon: Icons.privacy_tip,
  ),
  SpeedDialItem(
    title: 'Wikipedia',
    url: 'https://en.wikipedia.org',
    icon: Icons.menu_book,
  ),
  SpeedDialItem(
    title: 'CBC News',
    url: 'https://www.cbc.ca/news',
    icon: Icons.newspaper,
  ),
  SpeedDialItem(
    title: 'GitHub',
    url: 'https://github.com',
    icon: Icons.code,
  ),
  SpeedDialItem(
    title: 'YouTube',
    url: 'https://m.youtube.com',
    icon: Icons.play_circle_fill,
  ),
  SpeedDialItem(
    title: 'OpenStreetMap',
    url: 'https://www.openstreetmap.org',
    icon: Icons.map,
  ),
];

/// Common tracker & ad domains blocked when Tracker Shield is enabled.
const List<String> kBlockedTrackerHosts = [
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'google-analytics.com',
  'facebook.net',
  'scorecardresearch.com',
  'adservice.google.com',
  'taboola.com',
  'outbrain.com',
];

class HistoryEntry {
  final String title;
  final String url;
  final DateTime visitedAt;

  const HistoryEntry({
    required this.title,
    required this.url,
    required this.visitedAt,
  });
}

class BrowserTab {
  final String id;
  final WebViewController controller;
  String title;
  String url;
  bool isHome;
  int progress;

  BrowserTab({
    required this.id,
    required this.controller,
    this.title = 'New Tab',
    this.url = '',
    this.isHome = true,
    this.progress = 100,
  });
}

class PolarGoApp extends StatelessWidget {
  const PolarGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polar Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: PolarColors.royalBlue,
          onPrimary: PolarColors.white,
          secondary: PolarColors.powderBlue,
          onSecondary: PolarColors.deepRoyal,
          surface: PolarColors.white,
          onSurface: PolarColors.deepRoyal,
          outline: PolarColors.silver,
        ),
        scaffoldBackgroundColor: PolarColors.iceSurface,
      ),
      home: const PolarGoBrowserPage(),
    );
  }
}

class PolarGoBrowserPage extends StatefulWidget {
  const PolarGoBrowserPage({super.key});

  @override
  State<PolarGoBrowserPage> createState() => _PolarGoBrowserPageState();
}

class _PolarGoBrowserPageState extends State<PolarGoBrowserPage>
    with WidgetsBindingObserver {
  final TextEditingController _urlCtrl = TextEditingController();
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;

  final List<HistoryEntry> _history = [];
  int _trackersBlockedCount = 0;

  // Settings
  String _searchEngineId = 'ddg';
  bool _clearHistoryOnClose = true;
  bool _trackerShieldEnabled = true;

  SearchEngine get _activeEngine => kSearchEngines.firstWhere(
        (e) => e.id == _searchEngineId,
        orElse: () => kSearchEngines.first,
      );

  BrowserTab get _activeTab => _tabs[_activeTabIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _createNewTab();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_clearHistoryOnClose) {
      _wipeAllBrowsingData(silent: true);
    }
    _urlCtrl.dispose();
    super.dispose();
  }

  /// Automatically clears history, cookies, cache, and localStorage when the
  /// app is backgrounded/closed if "Clear History on Close" is enabled.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_clearHistoryOnClose &&
        (state == AppLifecycleState.detached ||
            state == AppLifecycleState.paused)) {
      _wipeAllBrowsingData(silent: true);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searchEngineId = prefs.getString('search_engine') ?? 'ddg';
      _clearHistoryOnClose = prefs.getBool('clear_on_close') ?? true;
      _trackerShieldEnabled = prefs.getBool('tracker_shield') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_engine', _searchEngineId);
    await prefs.setBool('clear_on_close', _clearHistoryOnClose);
    await prefs.setBool('tracker_shield', _trackerShieldEnabled);
  }

  BrowserTab _createNewTab({String? initialUrl}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    late BrowserTab tab;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(PolarColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest req) {
            if (_trackerShieldEnabled) {
              final host = Uri.tryParse(req.url)?.host.toLowerCase() ?? '';
              for (final blocked in kBlockedTrackerHosts) {
                if (host == blocked || host.endsWith('.$blocked')) {
                  if (mounted) {
                    setState(() => _trackersBlockedCount++);
                  }
                  return NavigationDecision.prevent;
                }
              }
            }
            return NavigationDecision.navigate;
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => tab.progress = progress);
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              tab.url = url;
              tab.isHome = false;
              if (_tabs.indexOf(tab) == _activeTabIndex) {
                _urlCtrl.text = url;
              }
            });
          },
          onPageFinished: (String url) async {
            final pageTitle = (await tab.controller.getTitle()) ?? url;
            if (!mounted) return;
            setState(() {
              tab.title = pageTitle.isNotEmpty ? pageTitle : url;
              tab.url = url;
              tab.progress = 100;
              if (_history.isEmpty || _history.first.url != url) {
                _history.insert(
                  0,
                  HistoryEntry(
                    title: tab.title,
                    url: url,
                    visitedAt: DateTime.now(),
                  ),
                );
              }
            });
          },
        ),
      );

    tab = BrowserTab(
      id: id,
      controller: controller,
      isHome: initialUrl == null,
    );

    setState(() {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
      _urlCtrl.text = initialUrl ?? '';
    });

    if (initialUrl != null) {
      _navigateToInput(initialUrl);
    }
    return tab;
  }

  void _navigateToInput(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return;

    String targetUrl;
    final looksLikeUrl = !trimmed.contains(' ') &&
        (trimmed.startsWith('http://') ||
            trimmed.startsWith('https://') ||
            trimmed.contains('.'));

    if (looksLikeUrl) {
      targetUrl = (trimmed.startsWith('http://') ||
              trimmed.startsWith('https://'))
          ? trimmed
          : 'https://$trimmed';
    } else {
      targetUrl =
          '${_activeEngine.queryPrefix}${Uri.encodeComponent(trimmed)}';
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _activeTab.isHome = false;
      _activeTab.url = targetUrl;
      _urlCtrl.text = targetUrl;
    });
    _activeTab.controller.loadRequest(Uri.parse(targetUrl));
  }

  /// DuckDuckGo-style "Burn / Wipe" action — clears history, cookies, cache & localStorage.
  Future<void> _wipeAllBrowsingData({bool silent = false}) async {
    try {
      await _cookieManager.clearCookies();
      for (final tab in _tabs) {
        await tab.controller.clearCache();
        await tab.controller.clearLocalStorage();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _history.clear();
        if (!silent) {
          _tabs.clear();
          _createNewTab();
        }
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: PolarColors.deepRoyal,
            content: Text(
              'Polar Go: All tabs, history, cookies & cache cleared!',
              style: TextStyle(color: PolarColors.white),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openTabsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PolarColors.iceSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Open Tabs (${_tabs.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PolarColors.deepRoyal,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PolarColors.royalBlue,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _createNewTab();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Tab'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final t = _tabs[idx];
                    final active = idx == _activeTabIndex;
                    return Card(
                      color: PolarColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: active
                              ? PolarColors.royalBlue
                              : PolarColors.silver,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          t.isHome ? Icons.home : Icons.public,
                          color: PolarColors.royalBlue,
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.isHome ? 'Polar Go Start Page' : t.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _tabs.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _tabs.removeAt(idx);
                                    if (_activeTabIndex >= _tabs.length) {
                                      _activeTabIndex = _tabs.length - 1;
                                    }
                                    _urlCtrl.text = _activeTab.url;
                                  });
                                  Navigator.pop(ctx);
                                },
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _activeTabIndex = idx;
                            _urlCtrl.text = t.url;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PolarColors.iceSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Browsing History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PolarColors.deepRoyal,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _wipeAllBrowsingData();
                    },
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    label: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No history recorded in this session.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final h = _history[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.history,
                          color: PolarColors.royalBlue,
                        ),
                        title: Text(
                          h.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          h.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateToInput(h.url);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrivacySettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PolarColors.iceSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Polar Go Privacy & Search',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PolarColors.deepRoyal,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: PolarColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: PolarColors.silver),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeTrackColor: PolarColors.royalBlue,
                        title: const Text(
                          'Clear History When App Closes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Auto-wipes history, cookies, cache & local storage on exit',
                        ),
                        value: _clearHistoryOnClose,
                        onChanged: (v) {
                          setSheetState(() => _clearHistoryOnClose = v);
                          setState(() => _clearHistoryOnClose = v);
                          _saveSettings();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: PolarColors.royalBlue,
                        title: const Text(
                          'Tracker & Ad Shield',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Blocked $_trackersBlockedCount tracker(s) this session',
                        ),
                        value: _trackerShieldEnabled,
                        onChanged: (v) {
                          setSheetState(() => _trackerShieldEnabled = v);
                          setState(() => _trackerShieldEnabled = v);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'DEFAULT SEARCH ENGINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: PolarColors.deepRoyal,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: kSearchEngines.map((engine) {
                    final selected = engine.id == _searchEngineId;
                    return ChoiceChip(
                      selected: selected,
                      selectedColor: PolarColors.powderBlue,
                      label: Text(
                        engine.name,
                        style: const TextStyle(
                          color: PolarColors.deepRoyal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onSelected: (_) {
                        setSheetState(() => _searchEngineId = engine.id);
                        setState(() => _searchEngineId = engine.id);
                        _saveSettings();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = _activeTab;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PolarColors.royalBlue,
        foregroundColor: PolarColors.white,
        titleSpacing: 8,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: PolarColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PolarColors.silver),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(
                _trackerShieldEnabled ? Icons.shield : Icons.public,
                color: PolarColors.royalBlue,
                size: 18,
              ),
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _navigateToInput,
                  style: const TextStyle(
                    fontSize: 14,
                    color: PolarColors.deepRoyal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search ${_activeEngine.name} or enter URL',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              if (_urlCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: Colors.black54,
                  ),
                  onPressed: () => setState(() => _urlCtrl.clear()),
                ),
            ],
          ),
        ),
        actions: [
          // DuckDuckGo-style Instant Burn / Wipe Button
          IconButton(
            icon: const Icon(
              Icons.local_fire_department,
              color: PolarColors.powderBlue,
            ),
            tooltip: 'Burn Tabs & Clear History Now',
            onPressed: () => _wipeAllBrowsingData(),
          ),
          // Tab Counter Button
          IconButton(
            tooltip: 'Tabs',
            onPressed: _openTabsSheet,
            icon: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: PolarColors.white, width: 1.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_tabs.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Privacy & Search Settings',
            onPressed: _openPrivacySettingsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!tab.isHome && tab.progress < 100)
            LinearProgressIndicator(
              value: tab.progress / 100.0,
              color: PolarColors.powderBlue,
              backgroundColor: PolarColors.deepRoyal,
              minHeight: 3,
            ),
          Expanded(
            child: tab.isHome
                ? _buildStartPage()
                : WebViewWidget(controller: tab.controller),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: PolarColors.white,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: PolarColors.deepRoyal),
              onPressed: () async {
                if (!tab.isHome && await tab.controller.canGoBack()) {
                  await tab.controller.goBack();
                } else {
                  setState(() {
                    tab.isHome = true;
                    tab.title = 'New Tab';
                    tab.url = '';
                    _urlCtrl.clear();
                  });
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward,
                color: PolarColors.deepRoyal,
              ),
              onPressed: () async {
                if (!tab.isHome && await tab.controller.canGoForward()) {
                  await tab.controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.home, color: PolarColors.royalBlue),
              onPressed: () {
                setState(() {
                  tab.isHome = true;
                  tab.title = 'New Tab';
                  tab.url = '';
                  _urlCtrl.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: PolarColors.deepRoyal),
              onPressed: () {
                if (!tab.isHome) tab.controller.reload();
              },
            ),
            IconButton(
              icon: const Icon(Icons.history, color: PolarColors.deepRoyal),
              tooltip: 'History',
              onPressed: _openHistorySheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/icon/polar_go_icon.png',
              width: 86,
              height: 86,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Polar Go',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: PolarColors.deepRoyal,
            ),
          ),
        ),
        Center(
          child: Text(
            _clearHistoryOnClose
                ? 'Auto-Clear on Close: ON • ${_activeEngine.name}'
                : 'Auto-Clear on Close: OFF • ${_activeEngine.name}',
            style: const TextStyle(
              fontSize: 12,
              color: PolarColors.royalBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 22),
        // Opera-style Speed Dial Grid
        const Text(
          'SPEED DIAL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: PolarColors.deepRoyal,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: kSpeedDial.map((item) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToInput(item.url),
              child: Container(
                decoration: BoxDecoration(
                  color: PolarColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PolarColors.silver),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: PolarColors.powderBlue,
                      foregroundColor: PolarColors.deepRoyal,
                      child: Icon(item.icon, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PolarColors.deepRoyal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
