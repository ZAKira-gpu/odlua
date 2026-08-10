// ─────────────────────────────────────────
// Widget: ChefSearchTab
// Description: Tab content showing chef search results. Queries
//              Firestore users collection filtered by chef role.
// Contains: Chef card list, Firestore query, profile navigation
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChefSearchTab extends StatefulWidget {
  final String searchQuery;

  const ChefSearchTab({super.key, this.searchQuery = ''});

  @override
  State<ChefSearchTab> createState() => _ChefSearchTabState();
}

class _ChefSearchTabState extends State<ChefSearchTab> {
  Stream<QuerySnapshot> _getChefsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'chef')
        .where('chefStatus', isEqualTo: 'approved')
        .snapshots();
  }

  List<DocumentSnapshot> _filterChefs(List<DocumentSnapshot> chefs) {
    if (widget.searchQuery.isEmpty) return chefs;

    return chefs.where((chef) {
      final data = chef.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final name = (data['name'] as String? ?? '').toLowerCase();
      final username = (data['username'] as String? ?? '').toLowerCase();
      final city = (data['city'] as String? ?? '').toLowerCase();
      final query = widget.searchQuery.toLowerCase();

      return name.contains(query) ||
          username.contains(query) ||
          city.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChefsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          DebugHelper.log('Error loading chefs: ${snapshot.error}');
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chefs = _filterChefs(snapshot.data?.docs ?? []);

        if (chefs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chefs.length,
          itemBuilder: (context, index) {
            final chef = chefs[index];
            final data = chef.data() as Map<String, dynamic>;
            return _buildChefCard(context, chef.id, data);
          },
        );
      },
    );
  }

  Widget _buildChefCard(
      BuildContext context, String chefId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'unknown_chef'.tr();
    final username = data['username'] as String? ?? '';
    final profilePicture = data['profilePicture'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final isVerified = data['isVerified'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChefProfileScreen(chefId: chefId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile picture
                Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mainColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: mainColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: profilePicture.isNotEmpty
                            ? Image.network(
                                profilePicture,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Iconsax.user,
                                  size: 32,
                                  color: mainColor,
                                ),
                              )
                            : Icon(
                                Iconsax.user,
                                size: 32,
                                color: mainColor,
                              ),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Chef info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Location and rating row
                      Row(
                        children: [
                          if (city.isNotEmpty) ...[
                            Icon(
                              Iconsax.location,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                city,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.user,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.searchQuery.isEmpty
                ? 'no_chefs_found'.tr()
                : 'no_results_for'.tr(args: [widget.searchQuery]),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'try_different_search'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.warning_2,
              size: 48,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'error_loading_chefs'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
