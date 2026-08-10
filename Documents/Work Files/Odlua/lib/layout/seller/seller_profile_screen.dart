// chef_profile_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/theme/custom_themes/main_colors.dart';
import '../dishes/custom_dish_request/custom_dish_request_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChefProfileScreen extends StatefulWidget {
  final String chefId;

  const ChefProfileScreen({super.key, required this.chefId});

  @override
  State<ChefProfileScreen> createState() => _ChefProfileScreenState();
}

class _ChefProfileScreenState extends State<ChefProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _chefData;
  List<QueryDocumentSnapshot> _chefDishes = [];
  List<QueryDocumentSnapshot> _chefReviews = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Validate chefId and load data
    if (widget.chefId.isEmpty) {
      DebugHelper.log('Invalid chefId: ${widget.chefId}');
      setState(() => _isLoading = false);
      return;
    }
    
    _loadChefData();
    _loadChefDishes();
    _loadChefReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChefData() async {
    try {
      final chefDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.chefId)
          .get();
      
      if (chefDoc.exists) {
        setState(() {
          _chefData = chefDoc.data();
        });
      } else {
        DebugHelper.log('Chef document does not exist for ID: ${widget.chefId}');
      }
    } catch (e) {
      DebugHelper.log('Error loading chef data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadChefDishes() async {
    try {
      final dishesSnapshot = await FirebaseFirestore.instance
          .collection('dishes')
          .where('chefID', isEqualTo: widget.chefId)
          .where('availableStock', isGreaterThan: 0) // Fixed field name
          .get();
      
      setState(() {
        _chefDishes = dishesSnapshot.docs;
      });
    } catch (e) {
      DebugHelper.log('Error loading chef dishes: $e');
      // Fallback: Try without stock filter
      try {
        final dishesSnapshot = await FirebaseFirestore.instance
            .collection('dishes')
            .where('chefID', isEqualTo: widget.chefId)
            .get();
        
        setState(() {
          _chefDishes = dishesSnapshot.docs;
        });
      } catch (e2) {
        DebugHelper.log('Fallback also failed: $e2');
      }
    }
  }

  Future<void> _loadChefReviews() async {
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('chefId', isEqualTo: widget.chefId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      setState(() {
        _chefReviews = reviewsSnapshot.docs;
      });
    } catch (e) {
      DebugHelper.log('Error loading chef reviews: $e');
      // Fallback: Try without ordering
      try {
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('chefId', isEqualTo: widget.chefId)
            .get();
        
        setState(() {
          _chefReviews = reviewsSnapshot.docs;
        });
      } catch (e2) {
        DebugHelper.log('Reviews fallback also failed: $e2');
      }
    }
  }

  void _refreshData() {
    if (widget.chefId.isEmpty) return;
    
    setState(() => _isLoading = true);
    _loadChefData();
    _loadChefDishes();
    _loadChefReviews();
  }

  // Safe data getters to prevent type errors
  String _getChefName() {
    final name = _chefData?['displayName'] ?? _chefData?['name'];
    if (name is String) return name;
    return 'Unknown Chef';
  }

  String _getChefPhotoUrl() {
    final photo = _chefData?['photoURL'] ?? _chefData?['photoUrl'];
    if (photo is String) return photo;
    return '';
  }

  double _getChefRating() {
    final rating = _chefData?['rating'];
    if (rating is double) return rating;
    if (rating is int) return rating.toDouble();
    return 0.0;
  }

  int _getReviewCount() {
    final count = _chefData?['reviewCount'];
    if (count is int) return count;
    if (count is String) return int.tryParse(count) ?? 0;
    return 0;
  }

  bool _getVerificationStatus() {
    final verified = _chefData?['verified'] ?? _chefData?['accountVerified'];
    if (verified is bool) return verified;
    if (verified is String) return verified == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading 
          ? _buildLoadingState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 280,
            collapsedHeight: 80,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black87),
                onPressed: _refreshData,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _buildHeaderSection(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: mainColor,
                  labelColor: mainColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(text: 'dishes'.tr()),
                    Tab(text: 'about'.tr()),
                    Tab(text: 'reviews'.tr()),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDishesTab(),
          _buildAboutTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final rating = _getChefRating();
    final reviewCount = _getReviewCount();
    final isVerified = _getVerificationStatus();

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.restaurant, size: 200, color: mainColor),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Profile Avatar with Verified Badge
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: mainColor.withOpacity(0.3), width: 3),
                      ),
                      child: ClipOval(
                        child: _getChefPhotoUrl().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _getChefPhotoUrl(),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _buildPlaceholderAvatar(),
                                errorWidget: (context, url, error) => _buildPlaceholderAvatar(),
                              )
                            : _buildPlaceholderAvatar(),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: mainColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chef Name and Rating
                Column(
                  children: [
                    Text(
                      _getChefName(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildOnlineStatusChip(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats Row
                _buildStatsRow(),
                const SizedBox(height: 20),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        color: Colors.grey.shade400,
        size: 40,
      ),
    );
  }

  Widget _buildOnlineStatusChip() {
    final isOnline = _chefData?['isOnline'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline 
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: isOnline ? Colors.green : Colors.grey,
            size: 8,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'online'.tr() : 'offline'.tr(),
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.restaurant,
            value: _chefDishes.length.toString(),
            label: 'dishes'.tr(),
          ),
          _buildStatItem(
            icon: Icons.access_time,
            value: '${_chefData?['avgDeliveryTime'] ?? '15'}',
            label: 'mins'.tr(),
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            value: '${_chefData?['completionRate'] ?? '95'}%',
            label: 'completion'.tr(),
          ),
          _buildStatItem(
            icon: Icons.message,
            value: '${_chefData?['responseRate'] ?? '98'}%',
            label: 'response'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: mainColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to chat screen
              _showComingSoonSnackbar('chat_feature_coming_soon'.tr());
            },
            icon: const Icon(Icons.chat, size: 20),
            label: Text('message'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: mainColor,
              side: BorderSide(color: mainColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CustomDishRequestScreen(
                  chefId: widget.chefId,
                  chefName: _getChefName(),
                )),
              );
            },
            icon: const Icon(Icons.add_circle, size: 20),
            label: Text('custom_dish'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoonSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildDishesTab() {
    if (_chefDishes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.restaurant_menu,
        title: 'no_dishes_available'.tr(),
        subtitle: 'chef_no_dishes_description'.tr(),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _chefDishes.length,
      itemBuilder: (context, index) {
        final dish = _chefDishes[index].data() as Map<String, dynamic>;
        return _buildDishCard(dish);
      },
    );
  }

  Widget _buildDishCard(Map<String, dynamic> dish) {
    final imageUrl = dish['imageURLs'] != null && dish['imageURLs'].isNotEmpty 
        ? dish['imageURLs'][0] 
        : null;
    final price = dish['price']?.toDouble() ?? 0.0;
    final rating = dish['ratingsAverage']?.toDouble() ?? 0.0;
    final ratingCount = dish['ratingsCount'] ?? 0;
    final availableStock = dish['availableStock'] ?? dish['quantityAvailable'] ?? 0;
    final isAvailable = availableStock > 0;

    return GestureDetector(
      onTap: () {
        // Navigate to dish details
        _showComingSoonSnackbar('dish_details_coming_soon'.tr());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dish Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildDishPlaceholder(),
                        errorWidget: (context, url, error) => _buildDishPlaceholder(),
                      )
                    : _buildDishPlaceholder(),
              ),
            ),
            
            // Dish Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dish Name
                    Text(
                      dish['name'] ?? 'Unnamed Dish',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($ratingCount)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    // Price and Availability
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          price == 0 ? 'free'.tr() : '€${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: mainColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAvailable 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAvailable ? 'available'.tr() : 'sold_out'.tr(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
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

  Widget _buildDishPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.fastfood,
        color: Colors.grey.shade400,
        size: 40,
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          _buildSection(
            icon: Icons.person,
            title: 'about_me'.tr(),
            child: Text(
              _chefData?['bio']?.toString() ?? 'no_bio_available'.tr(),
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Specialties Section
          _buildSection(
            icon: Icons.emoji_events,
            title: 'specialties'.tr(),
            child: _buildSpecialtiesSection(),
          ),
          const SizedBox(height: 24),

          // Experience Section
          _buildSection(
            icon: Icons.work,
            title: 'experience'.tr(),
            child: _buildExperienceSection(),
          ),
          const SizedBox(height: 24),

          // Location Section
          _buildSection(
            icon: Icons.location_on,
            title: 'location'.tr(),
            child: _buildLocationSection(),
          ),
          const SizedBox(height: 24),

          // Join Date
          _buildSection(
            icon: Icons.calendar_today,
            title: 'member_since'.tr(),
            child: _buildJoinDateSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesSection() {
    final specialties = _chefData?['specialties'];
    List<String> specialtyList = [];

    // Handle different data types for specialties
    if (specialties is List) {
      specialtyList = List<String>.from(specialties.whereType<String>());
    } else if (specialties is String) {
      specialtyList = [specialties];
    } else if (specialties is Map) {
      specialtyList = specialties.keys.map((key) => key.toString()).toList();
    }

    if (specialtyList.isEmpty) {
      specialtyList = ['Cooking', 'Baking', 'Traditional Recipes']; // Default fallback
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: specialtyList
          .map((specialty) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  specialty,
                  style: TextStyle(
                    color: mainColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildExperienceSection() {
    final yearsExperience = _chefData?['yearsExperience'] ?? 1;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$yearsExperience+',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.amber,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'years_experience'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final location = _chefData?['location'];
    String locationText = 'location_not_set'.tr();

    if (location is String) {
      locationText = location.isNotEmpty ? location : locationText;
    } else if (location is Map) {
      locationText = location['address']?.toString() ?? locationText;
    }

    return Row(
      children: [
        const Icon(Icons.location_on, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            locationText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinDateSection() {
    final joinDate = _chefData?['joinDate'];
    String joinDateText = 'Unknown';

    if (joinDate is String) {
      joinDateText = joinDate;
    } else if (joinDate is Timestamp) {
      final date = joinDate.toDate();
      joinDateText = '${date.day}/${date.month}/${date.year}';
    }

    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          joinDateText,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    if (_chefReviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.reviews,
        title: 'no_reviews'.tr(),
        subtitle: 'chef_no_reviews_description'.tr(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chefReviews.length,
      itemBuilder: (context, index) {
        final review = _chefReviews[index].data() as Map<String, dynamic>;
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating']?.toDouble() ?? 0.0;
    final reviewerName = review['reviewerName'] ?? 'Anonymous';
    final comment = review['comment'] ?? '';
    final date = review['createdAt'] != null 
        ? (review['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: mainColor.withOpacity(0.1),
                child: Icon(Icons.person, color: mainColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating.round() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (comment.isNotEmpty)
            Text(
              comment,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: mainColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}