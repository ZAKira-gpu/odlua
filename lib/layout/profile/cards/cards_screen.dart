// ─────────────────────────────────────────
// Screen: CardsScreen
// Description: Manage saved payment cards — add, view, and delete
//              credit/debit cards with validation.
// Contains: Card list, add-card form, card validator
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:credit_card_validator/credit_card_validator.dart';
import '../../../utils/theme/custom_themes/main_colors.dart' as AppColors;

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CreditCardValidator _cardValidator = CreditCardValidator();

  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cards')
            .orderBy('isDefault', descending: true)
            .get();

        setState(() {
          _cards = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'brand': data['brand'] ?? '',
              'number': data['number'] ?? '',
              'holder': data['holder'] ?? '',
              'expiry': data['expiry'] ?? '',
              'isDefault': data['isDefault'] ?? false,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load cards: ${e.toString()}';
      });
    }
  }

  Future<void> _setDefaultCard(String cardId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final batch = _firestore.batch();

        // Reset all cards to non-default
        final cardsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cards')
            .get();

        for (var doc in cardsSnapshot.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }

        // Set the selected card as default
        batch.update(
            _firestore
                .collection('users')
                .doc(user.uid)
                .collection('cards')
                .doc(cardId),
            {'isDefault': true});

        await batch.commit();
        await _loadCards(); // Reload to reflect changes
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'failed_set_default_card'.tr()}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeCard(String cardId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cards')
            .doc(cardId)
            .delete();

        await _loadCards(); // Reload to reflect changes

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('card_removed'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'failed_remove_card'.tr()}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addCardToFirebase(Map<String, dynamic> cardData) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // If this is the first card, set it as default
        if (_cards.isEmpty) {
          cardData['isDefault'] = true;
        } else {
          cardData['isDefault'] = false;
        }

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cards')
            .add(cardData);

        await _loadCards(); // Reload to reflect changes

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('card_added'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'failed_add_card'.tr()}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddCardSheet() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String brand = 'Visa';
    String cardNumber = '';
    String cardHolder = '';
    String expiryDate = '';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 24,
              right: 24,
              left: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Text(
                        'add_new_card'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Card Type
                    Text(
                      'card_type'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: brand,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 22),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        'Visa',
                        'Mastercard',
                        'American Express',
                        'Discover'
                      ]
                          .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (val) => setModalState(() => brand = val!),
                    ),
                    const SizedBox(height: 16),

                    // Card Number
                    Text(
                      'card_number'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'card_number_placeholder'.tr(),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(19),
                        CardNumberInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'card_number_required'.tr();
                        }

                        // Validate card number using the credit card validator
                        final validation = _cardValidator
                            .validateCCNum(value.replaceAll(' ', ''));
                        if (!validation.isValid) {
                          return 'invalid_card_number'.tr();
                        }

                        return null;
                      },
                      onChanged: (val) => cardNumber = val,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Expiry Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'expiry_date'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: 'expiry_date_placeholder'.tr(),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                keyboardType: TextInputType.datetime,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  ExpiryDateInputFormatter(),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'expiry_date_required'.tr();
                                  }

                                  if (value.length != 5) {
                                    return 'invalid_expiry_date'.tr();
                                  }

                                  // Validate expiry date
                                  final now = DateTime.now();
                                  final parts = value.split('/');
                                  if (parts.length != 2) {
                                    return 'invalid_expiry_date'.tr();
                                  }

                                  try {
                                    final month = int.parse(parts[0]);
                                    final year = int.parse('20${parts[1]}');

                                    if (month < 1 || month > 12) {
                                      return 'invalid_expiry_date'.tr();
                                    }

                                    final cardDate = DateTime(year, month + 1,
                                        0); // Last day of the month
                                    if (cardDate.isBefore(now)) {
                                      return 'card_expired'.tr();
                                    }
                                  } catch (e) {
                                    return 'invalid_expiry_date'.tr();
                                  }

                                  return null;
                                },
                                onChanged: (val) => expiryDate = val,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // CVV
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'cvv'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: '123',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'cvv_required'.tr();
                                  }

                                  if (value.length < 3 || value.length > 4) {
                                    return 'invalid_cvv'.tr();
                                  }

                                  return null;
                                },
                                onChanged: (val) {
                                  // CVV captured for validation only, not stored (PCI compliance)
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Card Holder
                    Text(
                      'card_holder'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'cardholder_name_placeholder'.tr(),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'card_holder_required'.tr();
                        }

                        if (value.length < 3) {
                          return 'invalid_card_holder'.tr();
                        }

                        return null;
                      },
                      onChanged: (val) => cardHolder = val,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isSaving = true);

                                  // Mask the card number (only store last 4 digits)
                                  final maskedNumber =
                                      '**** **** **** ${cardNumber.replaceAll(' ', '').substring(cardNumber.replaceAll(' ', '').length - 4)}';

                                  await _addCardToFirebase({
                                    'brand': brand,
                                    'number': maskedNumber,
                                    'holder': cardHolder,
                                    'expiry': expiryDate,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text('save_card'.tr()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Safe area padding for bottom navigation bar
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 8,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String cardId, String lastFourDigits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_card'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('confirm_delete_card'.tr(args: [lastFourDigits])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: TextStyle(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () {
              _removeCard(cardId);
              Navigator.pop(context);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('my_cards'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add, size: 24),
            onPressed: _showAddCardSheet,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.warning_2,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadCards,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('retry'.tr()),
                      ),
                    ],
                  ),
                )
              : _cards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.card,
                            size: 72,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'no_cards_found'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'add_your_first_card'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddCardSheet,
                            icon: const Icon(Iconsax.add, size: 20),
                            label: Text('add_card'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        final card = _cards[index];
                        final lastFourDigits = card['number'].length > 4
                            ? card['number']
                                .substring(card['number'].length - 4)
                            : card['number'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _getCardGradient(card['brand']),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Card Content
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          _getCardBrandImage(card['brand']),
                                          width: 50,
                                          height: 30,
                                          fit: BoxFit.contain,
                                        ),
                                        const Spacer(),
                                        if (card['isDefault'])
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'default'.tr(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 30),
                                    Text(
                                      card['number'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'card_holder'.tr(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                card['holder'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'expiry'.tr(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              card['expiry'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Action Buttons
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Row(
                                  children: [
                                    if (!card['isDefault'])
                                      IconButton(
                                        icon: const Icon(Iconsax.star,
                                            color: Colors.white, size: 22),
                                        onPressed: () =>
                                            _setDefaultCard(card['id']),
                                        tooltip: 'set_as_default'.tr(),
                                      ),
                                    IconButton(
                                      icon: const Icon(Iconsax.trash,
                                          color: Colors.white, size: 22),
                                      onPressed: () => _showDeleteConfirmation(
                                          card['id'], lastFourDigits),
                                      tooltip: 'remove'.tr(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  List<Color> _getCardGradient(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return [const Color(0xFFf7991e), const Color(0xFF1a1f71)];
      case 'mastercard':
        return [const Color(0xFFf46b45), const Color(0xFFeea849)];
      case 'american express':
        return [const Color(0xFF0070ba), const Color(0xFF154284)];
      case 'discover':
        return [const Color(0xFFff6000), const Color(0xFFd64000)];
      default:
        return [const Color(0xFF2c3e50), const Color(0xFF3498db)];
    }
  }

  String _getCardBrandImage(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return 'assets/payment_methods/visa.png';
      case 'mastercard':
        return 'assets/payment_methods/master-card.png';
      case 'american express':
        return 'assets/payment_methods/american_express.png';
      case 'discover':
        return 'assets/payment_methods/discover.png';
      default:
        return 'assets/images/credit_card.png';
    }
  }
}

// Custom input formatters
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String input = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (input.length > 16) {
      input = input.substring(0, 16);
    }

    String formatted = '';
    for (int i = 0; i < input.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += input[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String input = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (input.length > 4) {
      input = input.substring(0, 4);
    }

    if (input.length >= 2) {
      int month = int.tryParse(input.substring(0, 2)) ?? 0;
      if (month > 12) {
        input = '12${input.length > 2 ? input.substring(2) : ''}';
      }
    }

    String formatted = input;
    if (input.length > 2) {
      formatted = '${input.substring(0, 2)}/${input.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
