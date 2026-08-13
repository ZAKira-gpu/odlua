// ─────────────────────────────────────────
// Screen: SellerProfileScreen
// Description: Public-facing chef profile — shows chef info, dishes,
//              rating, and report/block options for other users.
// Contains: Profile header, dish listings, report sheet
// ─────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/services/moderation_service.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class ChefProfileScreen extends StatefulWidget {
  final String chefId;

  const ChefProfileScreen({super.key, required this.chefId});

  @override
  State<ChefProfileScreen> createState() => _ChefProfileScreenState();
}

class _ChefProfileScreenState extends State<ChefProfileScreen> {
  Map<String, dynamic>? _chefData;
  List<Dish> _dishes = [];
  bool _loading = true;
  bool _dishesLoading = true;
  String? _error;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _checkOwnProfile();
    _loadChefData();
    _loadChefDishes();
  }

  void _checkOwnProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isOwnProfile = uid != null && uid == widget.chefId;
  }

  Future<void> _loadChefData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.chefId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _chefData = doc.exists ? doc.data() : {};
          _loading = false;
        });
      }
    } catch (e) {
      DebugHelper.log('Error loading chef data: $e');
      if (mounted) {
        setState(() {
          _error = 'seller_profile.load_error'.tr();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadChefDishes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('dishes')
          .where('chefId', isEqualTo: widget.chefId)
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _dishes = snapshot.docs.map((d) => Dish.fromFirestore(d)).toList();
          _dishesLoading = false;
        });
      }
    } catch (e) {
      DebugHelper.log('Error loading chef dishes: $e');
      if (mounted) setState(() => _dishesLoading = false);
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'C';
    final parts = trimmed.split(' ');
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'C';
    }
    final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';
    final lastChar = parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = '$firstChar$lastChar'.toUpperCase();
    return initials.isNotEmpty ? initials : 'C';
  }

  void _showReportSheet() {
    final name = _chefData?['name'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChefReportSheet(
        chefId: widget.chefId,
        chefName: name,
        onSuccess: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      ),
    );
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _loading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: Container(height: 280, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Column(
                children: [
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.warning_2,
                        size: 36, color: Colors.red.shade300),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final name =
        _chefData?['name'] as String? ?? 'seller_profile.unknown_chef'.tr();
    final photoUrl = _chefData?['profileImageUrl'] as String?;
    final bio = _chefData?['bio'] as String?;
    final memberSince = (_chefData?['createdAt'] as Timestamp?)?.toDate();
    final showBio = bio != null && bio.isNotEmpty && bio != 'No bio available';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            'seller_profile'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          actions: [
            if (!_isOwnProfile)
              GestureDetector(
                onTap: _showReportSheet,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Iconsax.flag, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: _buildHeroHeader(name, photoUrl),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                // Bio card
                if (showBio) ...[
                  _buildCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mainColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Iconsax.message_text,
                              size: 18, color: mainColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            bio,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Member since
                if (memberSince != null) ...[
                  _buildInfoTile(
                    icon: Iconsax.calendar,
                    label: 'seller_profile.member_since'.tr(),
                    value: DateFormat.yMMMM().format(memberSince),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        // Dishes section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'seller_profile.dishes'.tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                if (!_dishesLoading)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_dishes.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: mainColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Dishes list
        if (_dishesLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_dishes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.personalcard,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'seller_profile.no_dishes'.tr(),
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDishCard(_dishes[index]),
                childCount: _dishes.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ───────────────────── Hero header ─────────────────────

  Widget _buildHeroHeader(String name, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mainColor,
            mainColorLight,
            const Color(0xFF1A9E50),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              _getInitials(name),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white.withValues(alpha: 0.2),
                        child: Center(
                          child: Text(
                            _getInitials(name),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.personalcard, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'seller_profile'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Dish card ─────────────────────

  Widget _buildDishCard(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DishDetailsScreen(dish: dish)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dish image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: dish.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: dish.imageUrls.first,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: Icon(Iconsax.image, color: Colors.grey.shade400),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: Icon(Iconsax.image, color: Colors.grey.shade400),
                    ),
            ),
            // Dish info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (dish.category.isNotEmpty)
                      Text(
                        dish.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          dish.price > 0
                              ? '€${dish.price.toStringAsFixed(2)}'
                              : 'dish_details.free'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: mainColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(Iconsax.star1,
                            size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 3),
                        Text(
                          dish.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  // ───────────────────── Helpers ─────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mainColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: mainColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChefReportSheet extends StatefulWidget {
  final String chefId;
  final String chefName;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  const _ChefReportSheet({
    required this.chefId,
    required this.chefName,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ChefReportSheet> createState() => _ChefReportSheetState();
}

class _ChefReportSheetState extends State<_ChefReportSheet> {
  bool _loading = false;
  bool _chefBlocked = false;

  Future<void> _report(String reason) async {
    setState(() => _loading = true);
    try {
      await ModerationService.instance.reportUser(
        userId: widget.chefId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('seller_profile.chef_reported'.tr());
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onError('moderation.report_failed'.tr());
    }
  }

  Future<void> _block() async {
    setState(() => _loading = true);
    try {
      await ModerationService.instance.blockUser(widget.chefId);
      setState(() => _chefBlocked = true);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('user_blocked'.tr());
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onError('failed_to_block_user'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      ('moderation.reason_inappropriate', Iconsax.warning_2),
      ('moderation.reason_spam', Iconsax.message_remove),
      ('moderation.reason_wrong_info', Iconsax.info_circle),
      ('moderation.reason_offensive', Iconsax.dislike),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'seller_profile.report_chef'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'seller_profile.report_chef_description'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ...reasons.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(r.$2, color: mainColor, size: 22),
                      title:
                          Text(r.$1.tr(), style: const TextStyle(fontSize: 15)),
                      onTap: () => _report(r.$1),
                    )),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Iconsax.user_remove,
                      color: Colors.red, size: 22),
                  title: Text(
                    'block_user'.tr(),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _chefBlocked ? null : _block,
                ),
              ],
            ),
    );
  }
}
