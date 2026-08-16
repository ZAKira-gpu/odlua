// ─────────────────────────────────────────
// Widget: HomeBannerWidget
// Description: Auto-scrolling promotional banner carousel on the home
//              screen. Fetches active banners from Firestore.
// Contains: CarouselSlider, dot indicator, Firestore query
// ─────────────────────────────────────────

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

/// Banners come from Firestore collection 'app_banners'.
/// If Firestore doesn't respond within 4 seconds, hardcoded fallback
/// banners are shown so the home screen is never empty.
///
/// Firestore schema: app_banners/{id}
///   isActive: bool, order: int,
///   imageUrl: String (optional),
///   title: Map<locale,String> | String,
///   subtitle: Map<locale,String> | String,
///   targetCountries: List<String> ([] = everywhere),
///   actionType: 'none' | 'url', actionValue: String
class HomeBannerWidget extends StatefulWidget {
  const HomeBannerWidget({super.key});

  @override
  State<HomeBannerWidget> createState() => _HomeBannerWidgetState();
}

// ---------------------------------------------------------------------------
// Hardcoded fallback banners (shown instantly / when Firestore is offline)
// ---------------------------------------------------------------------------
final List<Map<String, dynamic>> _kFallbackBanners = [
  {
    '_docId': 'fallback_1',
    'isActive': true,
    'order': 1,
    'imageUrl': '',
    'title': {
      'en': 'Share Homemade Food',
      'ar': 'شارك طعامك المنزلي',
      'de': 'Hausgemachtes Essen teilen',
      'fr': 'Partager la cuisine maison'
    },
    'subtitle': {
      'en': 'Connect with chefs near you',
      'ar': 'تواصل مع الطهاة بالقرب منك',
      'de': 'Verbinde dich mit Köchen',
      'fr': 'Connectez-vous avec des chefs'
    },
    'actionType': 'none',
    'actionValue': '',
    'targetCountries': [],
  },
  {
    '_docId': 'fallback_2',
    'isActive': true,
    'order': 2,
    'imageUrl': '',
    'title': {
      'en': 'Donate Surplus Food',
      'ar': 'تبرع بالطعام الزائد',
      'de': 'Überschuss spenden',
      'fr': 'Donner les surplus'
    },
    'subtitle': {
      'en': 'Help reduce food waste',
      'ar': 'ساعد في تقليل هدر الطعام',
      'de': 'Lebensmittelverschwendung reduzieren',
      'fr': 'Réduire le gaspillage alimentaire'
    },
    'actionType': 'none',
    'actionValue': '',
    'targetCountries': [],
  },
  {
    '_docId': 'fallback_3',
    'isActive': true,
    'order': 3,
    'imageUrl': '',
    'title': {
      'en': 'Exchange Dishes',
      'ar': 'تبادل الأطباق',
      'de': 'Gerichte tauschen',
      'fr': 'Échanger des plats'
    },
    'subtitle': {
      'en': 'Trade your cooking for something new',
      'ar': 'تداول طبخك بشيء جديد',
      'de': 'Tausche deine Kochkunst',
      'fr': 'Échangez votre cuisine'
    },
    'actionType': 'none',
    'actionValue': '',
    'targetCountries': [],
  },
];

// ---------------------------------------------------------------------------

class _HomeBannerWidgetState extends State<HomeBannerWidget> {
  List<Map<String, dynamic>> _banners = List.from(_kFallbackBanners);

  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  StreamSubscription<QuerySnapshot>? _sub;

  static const List<List<Color>> _palettes = [
    [Color(0xFFFF6B35), Color(0xFFFF9A5C)],
    [Color(0xFF6B48FF), Color(0xFF9B7DFF)],
    [Color(0xFF00C896), Color(0xFF00A87A)],
    [Color(0xFFFF4E6A), Color(0xFFFF7D93)],
    [Color(0xFF007BFF), Color(0xFF4DA6FF)],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _resetAutoScroll();
    _startListening();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _sub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startListening() {
    _sub =
        FirebaseFirestore.instance.collection('app_banners').snapshots().listen(
      (snap) {
        if (!mounted) return;
        final firestoreBanners = _applyFilters(snap.docs);
        if (firestoreBanners.isEmpty) return;
        setState(() {
          _banners = firestoreBanners;
          if (_currentPage >= _banners.length) {
            _currentPage = 0;
          }
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        _resetAutoScroll();
      },
      onError: (_) {
        // Keep fallback banners visible on any Firestore error.
      },
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final deviceCountry = WidgetsBinding
            .instance.platformDispatcher.locale.countryCode
            ?.toLowerCase() ??
        '';
    final result = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final raw = Map<String, dynamic>.from(doc.data() as Map);
      raw['_docId'] = doc.id;
      final active = raw['isActive'];
      if (active != true && active != 1 && active != 'true') continue;
      final start = raw['startDate'] is Timestamp
          ? (raw['startDate'] as Timestamp).toDate()
          : null;
      final end = raw['endDate'] is Timestamp
          ? (raw['endDate'] as Timestamp).toDate()
          : null;
      if (start != null && now.isBefore(start)) continue;
      if (end != null && now.isAfter(end)) continue;
      final countriesRaw = raw['targetCountries'];
      List<String> countries = [];
      if (countriesRaw is List && countriesRaw.isNotEmpty) {
        countries =
            countriesRaw.map((e) => e.toString().toLowerCase()).toList();
      } else if (countriesRaw is String && countriesRaw.isNotEmpty) {
        countries = [countriesRaw.toLowerCase()];
      }
      if (countries.isNotEmpty &&
          deviceCountry.isNotEmpty &&
          !countries.contains(deviceCountry)) {
        continue;
      }
      result.add(raw);
    }
    result.sort((a, b) {
      final oa = a['order'] is num
          ? (a['order'] as num)
          : num.tryParse(a['order']?.toString() ?? '0') ?? 0;
      final ob = b['order'] is num
          ? (b['order'] as num)
          : num.tryParse(b['order']?.toString() ?? '0') ?? 0;
      return oa.compareTo(ob);
    });
    return result;
  }

  void _resetAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_banners.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients || _banners.isEmpty) return;
      final next = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  String _t(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) {
      final lang = context.locale.languageCode;
      return val[lang]?.toString() ?? val['en']?.toString() ?? '';
    }
    return val.toString();
  }

  Future<void> _handleTap(Map<String, dynamic> banner) async {
    if (banner['actionType']?.toString() != 'url') return;
    final value = banner['actionValue']?.toString() ?? '';
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _banners.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, index) => _BannerCard(
                banner: _banners[index],
                fallbackColors: _palettes[index % _palettes.length],
                title: _t(_banners[index], 'title'),
                subtitle: _t(_banners[index], 'subtitle'),
                onTap: () => _handleTap(_banners[index]),
              ),
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                final active = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: active ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active ? mainColor : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  final List<Color> fallbackColors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BannerCard({
    required this.banner,
    required this.fallbackColors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (banner['imageUrl'] ??
            banner['image'] ??
            banner['image_url'] ??
            banner['url'] ??
            '')
        .toString()
        .trim();
    final isUrlAction = banner['actionType']?.toString() == 'url' &&
        (banner['actionValue']?.toString() ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _GradientBox(fallbackColors),
                    errorWidget: (_, __, ___) => _GradientBox(fallbackColors),
                  )
                : _GradientBox(fallbackColors),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0x00000000), Color(0xBB000000)],
                ),
              ),
            ),
            if (title.isNotEmpty || subtitle.isNotEmpty)
              PositionedDirectional(
                start: 16,
                end: isUrlAction ? 56 : 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            if (isUrlAction)
              PositionedDirectional(
                end: 14,
                bottom: 14,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    context.locale.languageCode == 'ar'
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GradientBox extends StatelessWidget {
  final List<Color> colors;
  const _GradientBox(this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
