// ─────────────────────────────────────────
// Screen: AccountTypeScreen
// Description: Post-signup role picker — buyer vs chef/seller.
// Contains: Account-type cards, role routing logic
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

/// This provides a cleaner separation between buyer and chef roles as per Issue #13.
class AccountTypeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const AccountTypeScreen({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('account_type.title'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'account_type.choose_your_path'.tr(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'account_type.subtitle'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Buyer Option
              _buildAccountTypeCard(
                context: context,
                icon: Icons.shopping_bag_rounded,
                title: 'account_type.buyer'.tr(),
                description: 'account_type.buyer_description'.tr(),
                color: Colors.blue,
                onTap: () => _selectBuyer(context),
              ),

              const SizedBox(height: 20),

              // Chef/Seller Option
              _buildAccountTypeCard(
                context: context,
                icon: Icons.restaurant_menu_rounded,
                title: 'account_type.chef'.tr(),
                description: 'account_type.chef_description'.tr(),
                color: mainColor,
                onTap: () => _selectChef(context),
              ),

              const Spacer(),

              // Note about changing later
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'account_type.can_change_later'.tr(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _selectBuyer(BuildContext context) {
    // User continues as buyer - navigate to home
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _selectChef(BuildContext context) {
    // User wants to be a chef - navigate to chef application screen
    Navigator.pushReplacementNamed(
      context,
      '/chef_application',
      arguments: userData,
    );
  }
}
