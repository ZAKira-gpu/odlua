// import 'package:flutter/material.dart';
// import 'package:odlua/app.dart';
// import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class FoodCategorySelectionScreen extends StatefulWidget {
//   final bool isFromSignup;

//   const FoodCategorySelectionScreen({super.key, this.isFromSignup = true});

//   @override
//   State<FoodCategorySelectionScreen> createState() =>
//       _FoodCategorySelectionScreenState();
// }

// class _FoodCategorySelectionScreenState
//     extends State<FoodCategorySelectionScreen> with SingleTickerProviderStateMixin {
//   final List<String> _categories = [
//     "Asian",
//     "Arab",
//     "African",
//     "Italian",
//     "French",
//     "Mexican",
//     "Breakfast",
//     "Lunch",
//     "Dinner",
//     "Snacks",
//     "Desserts",
//     "Salads",
//     "Drinks",
//     "Street Food",
//     "Vegan",
//     "Keto",
//     "Halal",
//     "Homemade",
//     "Spicy",
//     "Ladies' Picks",
//   ];

//   final Set<String> _selected = {};
//   bool _isSaving = false;
//   bool _isLoading = true;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();
    
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
    
//     _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeInOut,
//       ),
//     );
    
//     // Load existing preferences from Firebase
//     _loadPreferencesFromFirebase();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   // Load preferences from Firebase for the current user
//   Future<void> _loadPreferencesFromFirebase() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         DebugHelper.log("Loading preferences for user: ${user.uid}");
        
//         final doc = await FirebaseFirestore.instance
//             .collection("users")
//             .doc(user.uid)
//             .get();
            
//         if (doc.exists && doc.data() != null) {
//           final data = doc.data()!;
          
//           // Clear current selections before loading new ones
//           _selected.clear();
          
//           // Check if preferences exist in nested structure
//           if (data.containsKey('preferences') && data['preferences'] is Map) {
//             final preferences = data['preferences'] as Map<String, dynamic>;
//             if (preferences.containsKey('cuisineTypes') && preferences['cuisineTypes'] is List) {
//               final cuisineTypes = preferences['cuisineTypes'] as List<dynamic>;
              
//               // Filter and add only valid categories that exist in _categories
//               for (var item in cuisineTypes) {
//                 if (item is String && _categories.contains(item)) {
//                   _selected.add(item);
//                 }
//               }
//             }
//           } 
//           // Check if cuisineTypes exists at root level (backward compatibility)
//           else if (data.containsKey('cuisineTypes') && data['cuisineTypes'] is List) {
//             final cuisineTypes = data['cuisineTypes'] as List<dynamic>;
            
//             // Filter and add only valid categories that exist in _categories
//             for (var item in cuisineTypes) {
//               if (item is String && _categories.contains(item)) {
//                 _selected.add(item);
//               }
//             }
//           }
//         }
//       }
//     } catch (e) {
//       DebugHelper.log("Error loading preferences from Firebase: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("failed_to_load_preferences".tr()),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//         _animationController.forward();
//       }
//     }
//   }

//   void _toggleCategory(String category) {
//     setState(() {
//       if (_selected.contains(category)) {
//         _selected.remove(category);
//       } else {
//         _selected.add(category);
//       }
//     });
//   }

//   // Save preferences to Firebase for the current user
//   Future<void> _savePreferencesToFirebase(List<String> cuisineTypes) async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         final uid = user.uid;
        
//         // Save only the raw English keys to Firebase
//         await FirebaseFirestore.instance.collection("users").doc(uid).set({
//           "preferences": {
//             "cuisineTypes": cuisineTypes, // Raw keys only
//             "lastUpdated": FieldValue.serverTimestamp(),
//           }
//         }, SetOptions(merge: true));
//       }
//     } catch (e) {
//       DebugHelper.log("Error saving preferences: $e");
//       rethrow;
//     }
//   }

//   void _onContinue() async {
//     if (_selected.length < 3) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("select_at_least_three_categories".tr()),
//           backgroundColor: Colors.orange,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//       return;
//     }

//     setState(() => _isSaving = true);
    
//     try {
//       // Save to the current user's Firebase document (raw keys only)
//       await _savePreferencesToFirebase(_selected.toList());
      
//       if (widget.isFromSignup) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const OdluaLayout()),
//           (Route<dynamic> route) => false,
//         );
//       } else {
//         // For editing mode, just go back
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("preferences_updated_successfully".tr()),
//             backgroundColor: Colors.green,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("failed_to_save_preferences".tr()),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isSaving = false);
//       }
//     }
//   }

//   void _onSkip() async {
//     setState(() => _isSaving = true);
    
//     try {
//       // Save empty preferences to current user (raw keys only)
//       await _savePreferencesToFirebase([]);
      
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (context) => const OdluaLayout()),
//         (Route<dynamic> route) => false,
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("failed_to_save_preferences".tr()),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isSaving = false);
//       }
//     }
//   }

//   void _selectAll() {
//     setState(() {
//       _selected.addAll(_categories);
//     });
//   }

//   void _clearAll() {
//     setState(() {
//       _selected.clear();
//     });
//   }

//   // Refresh preferences from Firebase
//   Future<void> _refreshPreferences() async {
//     setState(() => _isLoading = true);
//     await _loadPreferencesFromFirebase();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("choose_food_categories".tr()),
//         centerTitle: true,
//         shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(
//             bottom: Radius.circular(20),
//           ),
//         ),
//         actions: [
//           // Refresh button to reload preferences
//           IconButton(
//             icon: const Icon(Icons.refresh_rounded),
//             onPressed: _refreshPreferences,
//             tooltip: "refresh_preferences".tr(),
//           ),
//           if (_selected.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.clear_all_rounded),
//               onPressed: _clearAll,
//               tooltip: "clear_all".tr(),
//             ),
//           IconButton(
//             icon: const Icon(Icons.select_all_rounded),
//             onPressed: _selectAll,
//             tooltip: "select_all".tr(),
//           ),
//           if (widget.isFromSignup)
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: TextButton(
//                 onPressed: _isSaving ? null : _onSkip,
//                 child: Text(
//                   "skip".tr(),
//                   style: TextStyle(
//                     color: _isSaving ? Colors.grey.shade400 : Colors.grey.shade700,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//               ),
//             )
//           : RefreshIndicator(
//               onRefresh: _refreshPreferences,
//               child: FadeTransition(
//                 opacity: _fadeAnimation,
//                 child: Padding(
//                   padding: const EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Header Section
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               "what_food_do_you_love".tr(),
//                               style: const TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.w700,
//                                 height: 1.2,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               _selected.isEmpty 
//                                   ? "select_categories_to_get_started".tr() 
//                                   : "select_at_least_three_categories".tr(),
//                               style: TextStyle(
//                                 fontSize: 15,
//                                 color: Colors.grey.shade600,
//                                 height: 1.4,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
                      
//                       // Selected Tags Section (Always visible)
//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.grey.shade50,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: Colors.grey.shade200,
//                             width: 1.5,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.05),
//                               blurRadius: 10,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   "your_selections".tr(),
//                                   style: const TextStyle(
//                                     fontSize: 17,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                                   decoration: BoxDecoration(
//                                     color: mainColor.withOpacity(0.1),
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Text(
//                                     "${_selected.length}/20",
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600,
//                                       color: mainColor,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),
                            
//                             if (_selected.isEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 12),
//                                 child: Center(
//                                   child: Column(
//                                     children: [
//                                       Icon(
//                                         Icons.category_rounded,
//                                         size: 40,
//                                         color: Colors.grey.shade400,
//                                       ),
//                                       const SizedBox(height: 8),
//                                       Text(
//                                         "no_categories_selected_yet".tr(),
//                                         style: TextStyle(
//                                           color: Colors.grey.shade500,
//                                           fontStyle: FontStyle.italic,
//                                         ),
//                                         textAlign: TextAlign.center,
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               )
//                             else
//                               Wrap(
//                                 spacing: 10,
//                                 runSpacing: 10,
//                                 children: _selected.map((category) {
//                                   return Chip(
//                                     label: Text(
//                                       category.tr(),
//                                       style: TextStyle(
//                                         color: mainColor,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                     backgroundColor: mainColor.withOpacity(0.1),
//                                     deleteIcon: Icon(Icons.close_rounded, size: 16, color: mainColor),
//                                     onDeleted: () => _toggleCategory(category),
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(10),
//                                     ),
//                                     padding: const EdgeInsets.symmetric(horizontal: 8),
//                                   );
//                                 }).toList(),
//                               ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
                      
//                       // Categories Grid Title
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: Text(
//                           "all_categories".tr(),
//                           style: const TextStyle(
//                             fontSize: 17,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
                      
//                       // Categories Grid
//                       Expanded(
//                         child: GridView.builder(
//                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: 2,
//                             mainAxisSpacing: 14,
//                             crossAxisSpacing: 14,
//                             childAspectRatio: 3.2,
//                           ),
//                           itemCount: _categories.length,
//                           itemBuilder: (context, index) {
//                             final category = _categories[index];
//                             final selected = _selected.contains(category);
                            
//                             return CategoryChip(
//                               category: category,
//                               selected: selected,
//                               onTap: () => _toggleCategory(category),
//                             );
//                           },
//                         ),
//                       ),
//                       const SizedBox(height: 20),
                      
//                       // Action Buttons
//                       Row(
//                         children: [
//                           if (!widget.isFromSignup)
//                             Expanded(
//                               child: OutlinedButton(
//                                 onPressed: _isSaving ? null : () => Navigator.pop(context),
//                                 style: OutlinedButton.styleFrom(
//                                   padding: const EdgeInsets.symmetric(vertical: 16),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(14),
//                                   ),
//                                   side: BorderSide(
//                                     color: Colors.grey.shade400,
//                                     width: 1.5,
//                                   ),
//                                 ),
//                                 child: Text(
//                                   "cancel".tr(),
//                                   style: TextStyle(
//                                     color: Colors.grey.shade700,
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 15,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           if (!widget.isFromSignup) const SizedBox(width: 14),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: (_selected.isNotEmpty && !_isSaving) ? _onContinue : null,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: mainColor,
//                                 foregroundColor: Colors.white,
//                                 padding: const EdgeInsets.symmetric(vertical: 16),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(14),
//                                 ),
//                                 elevation: 2,
//                                 shadowColor: mainColor.withOpacity(0.3),
//                               ),
//                               child: _isSaving
//                                   ? const SizedBox(
//                                       height: 22,
//                                       width: 22,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                   : Text(
//                                       widget.isFromSignup ? "save_and_continue".tr() : "save_changes".tr(),
//                                       style: const TextStyle(
//                                         fontWeight: FontWeight.w700,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//     );
//   }
// }

// // Custom Category Chip Widget for better UI
// class CategoryChip extends StatelessWidget {
//   final String category;
//   final bool selected;
//   final VoidCallback onTap;

//   const CategoryChip({
//     super.key,
//     required this.category,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//         decoration: BoxDecoration(
//           color: selected ? mainColor : Colors.white,
//           border: Border.all(
//             color: selected ? mainColor : Colors.grey.shade300,
//             width: selected ? 1.5 : 1.2,
//           ),
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(selected ? 0.15 : 0.08),
//               blurRadius: selected ? 12 : 6,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             AnimatedOpacity(
//               opacity: selected ? 1 : 0,
//               duration: const Duration(milliseconds: 200),
//               child: const Icon(
//                 Icons.check_circle_rounded,
//                 color: Colors.white,
//                 size: 20,
//               ),
//             ),
//             if (selected) const SizedBox(width: 8),
//             Flexible(
//               child: Text(
//                 category.tr(),
//                 style: TextStyle(
//                   color: selected ? Colors.white : Colors.grey.shade800,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 14,
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }