// ─────────────────────────────────────────
// Screen: FavoritesScreen
// Description: Shows the user’s saved/liked dishes with pull-to-
//              refresh and real-time Firestore sync.
// Contains: Favorites list, empty state, dish card navigation
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../dishes/dish_details_screen.dart';
import '../../utils/models/dish_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, dynamic> _chefDataCache = {};

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleDishFavorite(
      String dishId, bool isCurrentlyFavorite) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (isCurrentlyFavorite) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favoriteDishes')
            .doc(dishId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favoriteDishes')
            .doc(dishId)
            .set({'addedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      DebugHelper.log('Error toggling favorite: $e');
    }
  }

  Future<void> _toggleChefFavorite(
      String chefId, bool isCurrentlyFavorite) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (isCurrentlyFavorite) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favoriteChefs')
            .doc(chefId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favoriteChefs')
            .doc(chefId)
            .set({'addedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      DebugHelper.log('Error toggling favorite chef: $e');
    }
  }

  Future<Map<String, dynamic>?> _getChefData(String chefId) async {
    if (_chefDataCache.containsKey(chefId)) {
      return _chefDataCache[chefId];
    }

    try {
      final chefDoc = await _firestore.collection('users').doc(chefId).get();
      if (chefDoc.exists) {
        final data = chefDoc.data() as Map<String, dynamic>;
        _chefDataCache[chefId] = data;
        return data;
      }
    } catch (e) {
      DebugHelper.log('Error loading chef data: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('favorites_title'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: user == null
          ? _buildNoUserState()
          : Column(
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: mainColor,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: mainColor,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(text: 'favorites_dishes_tab'.tr()),
                        Tab(text: 'favorites_chefs_tab'.tr()),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFavoriteDishesTab(user.uid),
                      _buildFavoriteChefsTab(user.uid),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoUserState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'sign_in_for_favorites'.tr(),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteDishesTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteDishes')
          .snapshots(),
      builder: (context, favoriteSnapshot) {
        if (favoriteSnapshot.hasError) {
          return Center(child: Text('error_loading_favorites'.tr()));
        }

        if (favoriteSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final favoriteDishIds =
            favoriteSnapshot.data?.docs.map((doc) => doc.id).toList() ?? [];

        if (favoriteDishIds.isEmpty) {
          return _buildEmptyState('no_favorite_dishes'.tr());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('dishes')
              .where(FieldPath.documentId, whereIn: favoriteDishIds)
              .where('quantityAvailable', isGreaterThan: 0)
              .snapshots(),
          builder: (context, dishesSnapshot) {
            if (dishesSnapshot.hasError) {
              return Center(child: Text('error_loading_dishes'.tr()));
            }

            if (dishesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final favoriteDishes = dishesSnapshot.data?.docs
                    .map((doc) => Dish.fromFirestore(doc))
                    .toList() ??
                [];

            if (favoriteDishes.isEmpty) {
              return _buildEmptyState('no_favorite_dishes'.tr());
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: favoriteDishes.length,
              itemBuilder: (context, index) {
                final dish = favoriteDishes[index];
                return _buildFavoriteDishCard(dish);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteChefsTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteChefs')
          .snapshots(),
      builder: (context, favoriteSnapshot) {
        if (favoriteSnapshot.hasError) {
          return Center(child: Text('error_loading_favorites'.tr()));
        }

        if (favoriteSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final favoriteChefIds =
            favoriteSnapshot.data?.docs.map((doc) => doc.id).toList() ?? [];

        if (favoriteChefIds.isEmpty) {
          return _buildEmptyState('no_favorite_chefs'.tr());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: favoriteChefIds)
              .where('userType', isEqualTo: 'chef')
              .snapshots(),
          builder: (context, chefsSnapshot) {
            if (chefsSnapshot.hasError) {
              return Center(child: Text('error_loading_chefs'.tr()));
            }

            if (chefsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final favoriteChefs = chefsSnapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'name': data['displayName'] ?? 'Unknown Chef',
                    'rating': (data['rating'] ?? 0).toDouble(),
                    'reviewCount': data['reviewCount'] ?? 0,
                    'dishCount': data['dishCount'] ?? 0,
                    'verified': data['verified'] ?? false,
                    'image': data['photoURL'],
                    'categories': data['specialties'] ?? [],
                  };
                }).toList() ??
                [];

            if (favoriteChefs.isEmpty) {
              return _buildEmptyState('no_favorite_chefs'.tr());
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteChefs.length,
              itemBuilder: (context, index) {
                final chef = favoriteChefs[index];
                return _buildFavoriteChefCard(chef);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteDishCard(Dish dish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DishDetailsScreen(dish: dish),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Dish image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: dish.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            dish.imageUrls[0],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.fastfood,
                              color: Colors.grey.shade400,
                              size: 30,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.fastfood,
                          color: Colors.grey.shade400,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 12),
                // Dish details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _getChefData(dish.chefId),
                        builder: (context, snapshot) {
                          final chefName =
                              snapshot.data?['displayName'] ?? 'Unknown Chef';
                          return Text(
                            'By $chefName',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // Price and rating removed
                    ],
                  ),
                ),
                // Favorite button
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _toggleDishFavorite(dish.id, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteChefCard(Map<String, dynamic> chef) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: chef['image'] != null
                    ? NetworkImage(chef['image']) as ImageProvider
                    : const AssetImage('assets/images/placeholder.png'),
                child: chef['image'] == null
                    ? Icon(Icons.person, color: Colors.grey.shade400)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          chef['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (chef['verified'])
                          Icon(Icons.verified, color: mainColor, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Rating removed
                    Text(
                      '${chef['dishCount']} dishes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _toggleChefFavorite(chef['id'], true),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Categories/Specialties
          if (chef['categories'] != null &&
              (chef['categories'] as List).isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (chef['categories'] as List<dynamic>).map((category) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    category.toString(),
                    style: TextStyle(
                      color: mainColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChefProfileScreen(
                          chefId: chef['id'],
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mainColor,
                    side: BorderSide(color: mainColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('view_profile'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to chat with chef
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('message'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
