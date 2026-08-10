import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odlua/layout/client_orders/client_orders_screen.dart';
import 'package:odlua/layout/reservation/reservation_waiting_screen.dart';
import 'package:odlua/layout/seller/chef_order_management/chef_order_management_screen.dart';
import 'package:odlua/layout/profile/personal_data/personal_data_screen.dart';
import 'package:odlua/layout/profile/saved_address/saved_address_screen.dart';
import 'package:odlua/layout/profile/support/contact_support/contact_support_screen.dart';
import 'package:odlua/layout/profile/support/help_center/help_center_screen.dart';
import 'package:odlua/layout/profile/support/privacy_policy/privacy_policy_screen.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../authentication/login/login.dart';
import 'allergy_tags/allergy_tags_screen.dart';
import 'language_switcher/language_switcher_tile.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationsEnabled = true;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() {
        isLoading = true;
        isError = false;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'user_not_authenticated'.tr();
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          userData = _sanitizeUserData(data);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMessage = 'user_data_not_found'.tr();
        });
      }
    } on FirebaseException catch (e) {
      DebugHelper.log('Firebase Error fetching user data: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = 'firebase_error'.tr(args: [e.code]);
      });
    } on TimeoutException catch (_) {
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = 'request_timeout'.tr();
      });
    } catch (e) {
      DebugHelper.log('Unexpected error fetching user data: $e');
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = 'unexpected_error'.tr();
      });
    }
  }

  Map<String, dynamic> _sanitizeUserData(Map<String, dynamic>? data) {
    if (data == null) return {};

    return {
      'name': data['name']?.toString() ?? '',
      'email': data['email']?.toString() ?? '',
      'photoURL': data['photoURL']?.toString(),
      'userType': data['userType']?.toString(),
      'isChef': data['isChef'] is bool ? data['isChef'] : false,
      'hasListings': data['hasListings'] is bool ? data['hasListings'] : false,
      'accountVerified':
          data['accountVerified'] is bool ? data['accountVerified'] : false,
      'location': _sanitizeLocationData(data['location']),
      'createdAt': data['createdAt'],
      'lastLogin': data['lastLogin'],
    };
  }

  dynamic _sanitizeLocationData(dynamic location) {
    if (location == null) return null;
    if (location is String) return location;
    if (location is Map) {
      return {
        'address': location['address']?.toString(),
        'city': location['city']?.toString(),
        'country': location['country']?.toString(),
        'latitude': location['latitude'] is num
            ? location['latitude'].toDouble()
            : null,
        'longitude': location['longitude'] is num
            ? location['longitude'].toDouble()
            : null,
      };
    }
    return null;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final names = name.trim().split(' ');
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  String _getLocationSubtitle() {
    if (userData?['location'] == null) {
      return 'manage_delivery_locations'.tr();
    }

    if (userData!['location'] is String) {
      return userData!['location'] as String;
    }

    if (userData!['location'] is Map) {
      final locationMap = userData!['location'] as Map;
      return locationMap['address']?.toString() ??
          'manage_delivery_locations'.tr();
    }

    return 'manage_delivery_locations'.tr();
  }

  bool get _hasChefListings {
    return userData?['userType'] == 'chef' ||
        userData?['isChef'] == true ||
        userData?['hasListings'] == true;
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      DebugHelper.log('Error signing out: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sign_out_failed'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('profile_title'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchUserData,
            tooltip: 'refresh_profile'.tr(),
          ),
        ],
      ),
      body: _buildBody(context, user),
    );
  }

  Widget _buildBody(BuildContext context, User? user) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'failed_to_load_profile'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User Avatar Section
          _buildUserAvatarSection(),
          const SizedBox(height: 16),

          // User Info Section
          _buildUserInfoSection(user),
          const SizedBox(height: 32),

          // Personal Section
          _buildSectionTitle('profile_section_personal'.tr()),
          _buildPersonalDataTile(),

          // Buyer Features
          _buildSectionTitle('profile_section_buyer'.tr()),
          _buildBuyerTiles(),

          // Seller Features
          _buildSectionTitle('profile_section_seller'.tr()),
          _buildSellerTiles(),

          // Common Features
          _buildSectionTitle('profile_section_common'.tr()),
          _buildCommonTiles(),

          // Preferences
          _buildPreferencesSection(),

          // Support
          _buildSupportSection(),

          const Divider(height: 48, thickness: 0.6, color: Color(0xFFEAEAEA)),

          // Sign Out
          _buildSignOutButton(),
        ],
      ),
    );
  }

  Widget _buildUserAvatarSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: mainColor.withOpacity(0.3),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: userData?['photoURL'] != null
                ? CachedNetworkImage(
                    imageUrl: userData!['photoURL']!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : Container(
                    color: mainColor.withOpacity(0.15),
                    child: Center(
                      child: Text(
                        _getInitials(userData?['name'] ?? 'User'),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mainColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalDataScreen(),
                  ),
                ).then((_) => _fetchUserData());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection(User? user) {
    return Column(
      children: [
        // User Name
        Text(
          userData?['name']?.isNotEmpty == true
              ? userData!['name']!
              : 'user_not_found'.tr(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // User UID and Badges
        if (user != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Text(
                  'UID: ${user.uid.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'Monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_hasChefListings) ...[
                  const SizedBox(height: 8),
                  _buildBadge(
                    icon: Icons.storefront_rounded,
                    text: 'active_seller'.tr(),
                    color: mainColor,
                  ),
                ],
                if (userData?['accountVerified'] == true) ...[
                  const SizedBox(height: 4),
                  _buildBadge(
                    icon: Icons.verified,
                    text: 'verified_account'.tr(),
                    color: Colors.green,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataTile() {
    return _buildFloatingTile(
      icon: Iconsax.profile_circle,
      title: 'profile_personal_data'.tr(),
      subtitle: 'update_your_profile'.tr(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PersonalDataScreen()),
      ).then((_) => _fetchUserData()),
    );
  }

  Widget _buildBuyerTiles() {
    return Column(
      children: [
        _buildFloatingTile(
          icon: Iconsax.shopping_bag,
          title: 'profile_my_orders'.tr(),
          subtitle: 'view_order_history'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
          ),
        ),
        _buildFloatingTile(
          icon: Iconsax.timer,
          title: 'active_reservations'.tr(),
          subtitle: 'check_reservation_status'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReservationWaitingScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerTiles() {
    return Column(
      children: [
        _buildFloatingTile(
          icon: Iconsax.shop,
          title: 'chef_reservations'.tr(),
          subtitle: 'manage_customer_reservations'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ChefOrderManagementScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonTiles() {
    return Column(
      children: [
        _buildFloatingTile(
          icon: Iconsax.location,
          title: 'profile_saved_addresses'.tr(),
          subtitle: _getLocationSubtitle(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      children: [
        _buildSectionTitle('profile_section_preferences'.tr()),
        _buildFloatingTile(
          icon: Iconsax.warning_2,
          title: 'profile_allergy_tags'.tr(),
          subtitle: 'manage_allergy_info'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllergyTagsScreen()),
          ).then((_) => _fetchUserData()),
        ),
        const LanguageSwitcherTile(),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      children: [
        _buildSectionTitle('profile_section_support'.tr()),
        _buildFloatingTile(
          icon: Iconsax.message_question,
          title: 'profile_help_center'.tr(),
          subtitle: 'get_help_support'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
          ),
        ),
        _buildFloatingTile(
          icon: Iconsax.call,
          title: 'profile_contact_support'.tr(),
          subtitle: 'contact_our_team'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
          ),
        ),
        _buildFloatingTile(
          icon: Iconsax.shield_tick,
          title: 'profile_privacy_policy'.tr(),
          subtitle: 'read_privacy_policy'.tr(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildFloatingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: mainColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _signOut,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          'sign_out'.tr(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
