import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/theme/custom_themes/main_colors.dart';

class CustomDishRequestScreen extends StatefulWidget {
  final String chefId;
  final String chefName;

  const CustomDishRequestScreen({super.key, required this.chefId, required this.chefName});

  @override
  State<CustomDishRequestScreen> createState() => _CustomDishRequestScreenState();
}

class _CustomDishRequestScreenState extends State<CustomDishRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _name = '';
  String _ingredients = '';
  String _dietNotes = '';
  int _servings = 1;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_complete_all_fields'.tr())),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('authentication_required'.tr())),
        );
        return;
      }

      // Create custom dish request
      await _firestore.collection('customRequests').add({
        'customerId': user.uid,
        'chefId': widget.chefId,
        'dishName': _name,
        'ingredients': _ingredients,
        'dietaryNotes': _dietNotes,
        'servings': _servings,
        'preferredDate': _selectedDate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'priceEstimate': null, // To be set by chef
        'chefResponse': null,
      });

      // Also create a chat message for this request
      await _firestore.collection('chats').add({
        'participants': [user.uid, widget.chefId],
        'lastMessage': '${'custom_request_from'.tr()}: $_name',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'customRequest': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('request_submitted_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('request_submission_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'select_preferred_date'.tr(),
      confirmText: 'confirm'.tr(),
      cancelText: 'cancel'.tr(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('custom_dish_request'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with chef info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: mainColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'request_for_chef'.tr(args: [widget.chefName]),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildInput(
                    label: 'dish_name'.tr(),
                    hint: 'dish_name_hint'.tr(),
                    onSaved: (val) => _name = val ?? '',
                    validator: (value) => value!.isEmpty ? 'dish_name_required'.tr() : null,
                    icon: Icons.restaurant,
                  ),
                  const SizedBox(height: 20),
                  _buildInput(
                    label: 'ingredients'.tr(),
                    hint: 'ingredients_hint'.tr(),
                    onSaved: (val) => _ingredients = val ?? '',
                    validator: (value) => value!.isEmpty ? 'ingredients_required'.tr() : null,
                    maxLines: 3,
                    icon: Icons.shopping_basket,
                  ),
                  const SizedBox(height: 20),
                  _buildInput(
                    label: 'dietary_notes'.tr(),
                    hint: 'dietary_notes_hint'.tr(),
                    onSaved: (val) => _dietNotes = val ?? '',
                    maxLines: 2,
                    icon: Icons.health_and_safety,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInput(
                          label: 'servings'.tr(),
                          hint: 'servings_hint'.tr(),
                          onSaved: (val) => _servings = int.tryParse(val ?? '1') ?? 1,
                          keyboardType: TextInputType.number,
                          icon: Icons.people,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatePicker(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'submit_request'.tr(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String hint,
    required FormFieldSetter<String> onSaved,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: mainColor) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor, width: 2),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'preferred_date'.tr(),
          prefixIcon: Icon(Icons.calendar_today, color: mainColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'select_date'.tr()
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: mainColor),
          ],
        ),
      ),
    );
  }
}