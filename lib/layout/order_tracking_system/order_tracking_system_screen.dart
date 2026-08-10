// ─────────────────────────────────────────
// Screen: OrderTrackingSystemScreen (DISABLED)
// Description: Real-time order tracking with map, status timeline,
//              and ETA. Currently fully commented out.
// Contains: Google Map, status stepper, location stream
// ─────────────────────────────────────────

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:step_progress_indicator/step_progress_indicator.dart';
// import '../../utils/theme/custom_themes/main_colors.dart';

// class OrderTrackingScreen extends StatelessWidget {
//   final String dishName;
//   final String chefName;
//   final String estimatedTime;
//   final int currentStep; // 0: Pending, 1: Accepted, 2: Ready
//   final String orderId;
//   final VoidCallback? onCancelOrder;

//   const OrderTrackingScreen({
//     super.key,
//     required this.dishName,
//     required this.chefName,
//     required this.estimatedTime,
//     required this.currentStep,
//     required this.orderId,
//     this.onCancelOrder,
//   });

//   // Validate current step to prevent UI issues
//   int _getValidatedCurrentStep() {
//     final totalSteps = 3; // Pending, Accepted, Pickup Ready
//     if (currentStep < 0) return 0;
//     if (currentStep >= totalSteps) return totalSteps - 1;
//     return currentStep;
//   }

//   Future<void> _handleCancelOrder(BuildContext context) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Cancel Order'),
//         content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('No'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Yes, Cancel'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       try {
//         // Call the provided cancel callback or implement your own logic
//         if (onCancelOrder != null) {
//           onCancelOrder!();
//         } else {
//           // Default implementation - update Firestore
//           await FirebaseFirestore.instance
//               .collection('orders')
//               .doc(orderId)
//               .update({
//             'status': 'cancelled',
//             'cancelledAt': DateTime.now(),
//             'updatedAt': DateTime.now(),
//           });
//         }

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Order cancelled successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.pop(context);
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to cancel order: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final List<String> steps = ["Pending", "Accepted", "Pickup Ready"];
//     final validatedStep = _getValidatedCurrentStep();

//     return Scaffold(
//       appBar: AppBar(title: const Text("Order Tracking")),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             // Order Title
//             Text(
//               dishName,
//               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             Text("by $chefName", style: const TextStyle(fontSize: 16)),

//             const SizedBox(height: 32),

//             // Step Progress Bar
//             StepProgressIndicator(
//               totalSteps: steps.length,
//               currentStep: validatedStep + 1,
//               size: 8,
//               padding: 0,
//               selectedColor: mainColor,
//               unselectedColor: Colors.grey.shade300,
//               roundedEdges: const Radius.circular(10),
//             ),

//             const SizedBox(height: 16),

//             // Labels for each step
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: steps.map((s) => Text(s)).toList(),
//             ),

//             const SizedBox(height: 32),

//             // Estimated Pickup Time
//             Row(
//               children: [
//                 const Icon(Icons.timer, color: Colors.grey),
//                 const SizedBox(width: 8),
//                 Text("Estimated pickup: $estimatedTime"),
//               ],
//             ),

//             const Spacer(),

//             // Buttons
//             ElevatedButton.icon(
//               onPressed: () {
//                 Navigator.pushNamed(context, '/chat');
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: mainColor,
//                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               icon: const Icon(Icons.chat),
//               label: const Text("Chat with Chef"),
//             ),

//             const SizedBox(height: 12),

//             TextButton(
//               onPressed: () => _handleCancelOrder(context),
//               style: TextButton.styleFrom(foregroundColor: Colors.red),
//               child: const Text("Cancel Order"),
//             ),

//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }
// }
