// ─────────────────────────────────────────
// Widget: RatingDialog (DISABLED)
// Description: Star-rating dialog for rating chefs or dishes after
//              an order. Currently fully commented out.
// Contains: Star rating bar, review text, Firestore submission
// ─────────────────────────────────────────

/*
// RATING SYSTEM TEMPORARILY DISABLED
// This entire file has been commented out to disable the rating system
// Original implementation preserved below

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class RatingDialog extends StatefulWidget {
  final VoidCallback? onSubmit;

  const RatingDialog({
    super.key,
    this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'rate_your_order'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            
            // Comment Field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'write_review_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'cancel'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'rating': _rating,
                        'comment': _commentController.text.trim(),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('submit_rating'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

*/

// PLACEHOLDER CLASS FOR COMPATIBILITY
import 'package:flutter/material.dart';

class RatingDialog extends StatelessWidget {
  final VoidCallback? onSubmit;

  const RatingDialog({
    super.key,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Return empty container - rating system disabled
    return const SizedBox.shrink();
  }
}
