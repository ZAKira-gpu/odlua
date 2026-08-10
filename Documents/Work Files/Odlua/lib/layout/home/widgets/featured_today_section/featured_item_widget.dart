import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/models/dish_model.dart';

class FeaturedItem extends StatelessWidget {
  final Dish dish;

  const FeaturedItem({
    super.key,
    required this.dish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              dish.imageUrls.isNotEmpty
                  ? dish.imageUrls[0]
                  : 'https://via.placeholder.com/100x100',
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  dish.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Price OR Free
                dish.price == 0
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'featured.free_label'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                  ],
                )
                    : Text(
                  '\$${dish.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

                // Rating + Distance
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(dish.rating.toStringAsFixed(1)),
                    const Spacer(),
                    Text(
                      '${dish.distance != -1 ? dish.distance.toStringAsFixed(1) : 'featured.not_available'.tr()} km',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}