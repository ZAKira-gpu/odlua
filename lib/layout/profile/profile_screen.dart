// ─────────────────────────────────────────
// Screen: ProfileScreen
// Description: Current user’s profile hub — avatar, stats, settings
//              tiles (personal data, addresses, cards, allergies,
//              language, support, logout, delete account).
// Contains: Profile header, settings list, sign-out, navigation
// ─────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/authentication/login/login.dart';
import 'package:odlua/layout/client_orders/client_orders_screen.dart';
import 'package:odlua/layout/profile/allergy_tags/allergy_tags_screen.dart';
import 'package:odlua/layout/profile/delete_account/delete_account_screen.dart';
import 'package:odlua/layout/profile/personal_data/personal_data_screen.dart';
import 'package:odlua/layout/profile/saved_addresses.dart';
import 'package:odlua/layout/profile/support/contact_support/contact_support_screen.dart';
import 'package:odlua/layout/profile/support/help_center/help_center_screen.dart';
import 'package:odlua/layout/profile/support/privacy_policy/privacy_policy_screen.dart';
import 'package:odlua/layout/profile/support/prohibited_use/prohibited_use_policy_screen.dart';
import 'package:odlua/layout/profile/support/seller_agreement/seller_agreement_screen.dart';
import 'package:odlua/layout/profile/support/terms_of_service/terms_of_service_screen.dart';
import 'package:odlua/utils/cubit/cubit.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isChef = false;
  bool _isOrganization = false;
  Map<String, dynamic>? userData;

  String get _displayName =>
      userData?['name'] as String? ??
      FirebaseAuth.instance.currentUser?.displayName ??
      'User'.tr();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        setState(() {
          userData = doc.data();
          _isChef = userData?['isChef'] == true;
          _isOrganization = userData?['isOrganization'] == true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleHideAddressTitle(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'hideAddressTitle': value});

    if (mounted) {
      setState(() {
        userData?['hideAddressTitle'] = value;
      });
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(' ');
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
    }
    final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';
    final lastChar = parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = '$firstChar$lastChar'.toUpperCase();
    return initials.isNotEmpty ? initials : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          // Avatar with glow
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: mainColor.withValues(alpha: 0.28),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: mainColor.withValues(alpha: 0.1),
                                border: Border.all(
                                    color: mainColor.withValues(alpha: 0.3),
                                    width: 2.5),
                              ),
                              child: ClipOval(
                                child: (userData?['photoURL'] != null &&
                                        userData!['photoURL']!
                                            .toString()
                                            .isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: userData!['photoURL']!,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Center(
                                          child: Text(
                                            _getInitials(_displayName),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: mainColor,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _getInitials(_displayName),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: mainColor,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Name
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Email
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          // Badges row
                          if (_isChef || _isOrganization) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (_isChef)
                                  _buildBadge(
                                    icon: Iconsax.verify5,
                                    label: 'verified_chef'.tr(),
                                    color: mainColor,
                                  ),
                                if (_isOrganization)
                                  _buildBadge(
                                    icon: Icons.business_rounded,
                                    label: 'organization'.tr(),
                                    color: const Color(0xFF3B82F6),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─────────────────────────────────────────────────────────
                    // ACCOUNT SECTION
                    // ─────────────────────────────────────────────────────────
                    _buildSectionLabel('account'.tr()),
                    const SizedBox(height: 10),

                    _buildCard(
                      icon: Iconsax.user,
                      title: 'profile_personal_data'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonalDataScreen()),
                      ).then((_) => _fetchUserData()),
                    ),

                    // Organizations don't use saved personal addresses
                    if (!_isOrganization)
                      _buildCard(
                        icon: Iconsax.location,
                        title: 'profile_saved_addresses'.tr(),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SavedAddressesScreen()),
                        ),
                      ),

                    _buildCard(
                      icon: Iconsax.shopping_bag,
                      title: 'profile_my_orders'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClientOrdersScreen()),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─────────────────────────────────────────────────────────
                    // PREFERENCES SECTION
                    // ─────────────────────────────────────────────────────────
                    _buildSectionLabel('preferences'.tr()),
                    const SizedBox(height: 10),

                    _buildCard(
                      icon: Iconsax.warning_2,
                      title: 'profile_allergy_tags'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AllergyTagsScreen()),
                      ).then((_) => _fetchUserData()),
                    ),

                    // Language Switcher - matches card style
                    _buildLanguageCard(context),

                    // Privacy toggle for chefs
                    if (_isChef) ...[
                      const SizedBox(height: 20),

                      // ─────────────────────────────────────────────────────────
                      // PRIVACY SECTION (Chef only)
                      // ─────────────────────────────────────────────────────────
                      _buildSectionLabel('privacy'.tr()),
                      const SizedBox(height: 10),

                      _buildToggleCard(
                        icon: Iconsax.eye_slash,
                        title: 'hide_address_title'.tr(),
                        subtitle: 'hide_address_title_desc'.tr(),
                        value: userData?['hideAddressTitle'] == true,
                        onChanged: (value) => _toggleHideAddressTitle(value),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ─────────────────────────────────────────────────────────
                    // SUPPORT SECTION
                    // ─────────────────────────────────────────────────────────
                    _buildSectionLabel('support'.tr()),
                    const SizedBox(height: 10),

                    _buildCard(
                      icon: Iconsax.message_question,
                      title: 'profile_help_center'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen()),
                      ),
                    ),

                    _buildCard(
                      icon: Iconsax.call,
                      title: 'profile_contact_support'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContactSupportScreen()),
                      ),
                    ),

                    _buildCard(
                      icon: Iconsax.shield_tick,
                      title: 'profile_privacy_policy'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),

                    _buildCard(
                      icon: Iconsax.document_text,
                      title: 'terms_of_service'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen()),
                      ),
                    ),

                    if (_isChef)
                      _buildCard(
                        icon: Iconsax.document,
                        title: 'seller_agreement'.tr(),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SellerAgreementScreen()),
                        ),
                      ),

                    _buildCard(
                      icon: Iconsax.danger,
                      title: 'prohibited_use_policy'.tr(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProhibitedUsePolicyScreen()),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─────────────────────────────────────────────────────────
                    // ACCOUNT ACTIONS
                    // ─────────────────────────────────────────────────────────
                    _buildCard(
                      icon: Iconsax.logout,
                      title: 'logout'.tr(),
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      onTap: _signOut,
                    ),

                    _buildCard(
                      icon: Iconsax.trash,
                      title: 'delete_account'.tr(),
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeleteAccountScreen()),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'app_version'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBadge(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
    final currentLocale = context.locale;
    final languageName = _getLanguageDisplayName(currentLocale.languageCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLanguageBottomSheet(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Iconsax.language_circle,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile_select_language'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        languageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context) {
    final supportedLocales = context.supportedLocales;
    final currentLocale = context.locale;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
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
                  'select_language'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                ...supportedLocales.map((locale) {
                  final isSelected = locale == currentLocale;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? mainColor.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: mainColor.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: ListTile(
                      onTap: () {
                        context.setLocale(locale);
                        Navigator.pop(ctx);
                      },
                      leading: Text(
                        _getFlag(locale.languageCode),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        _getLanguageDisplayName(locale.languageCode),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? mainColor : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Iconsax.tick_circle5,
                              color: mainColor, size: 22)
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLanguageDisplayName(String lang) {
    switch (lang) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }

  String _getFlag(String lang) {
    switch (lang) {
      case 'en':
        return '🇺🇸';
      case 'ar':
        return '🇸🇦';
      case 'de':
        return '🇩🇪';
      case 'fr':
        return '🇫🇷';
      default:
        return '🌐';
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.grey.shade600)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconColor ?? Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: mainColor,
            ),
          ],
        ),
      ),
    );
  }
}
