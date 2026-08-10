// ─────────────────────────────────────────
// Screen: EditLocationScreen
// Description: Update the user’s primary location via GPS or manual
//              address entry. Writes to Firestore user profile.
// Contains: Location selector, address form, Firestore update
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:odlua/utils/models/structured_address_model.dart';

class EditLocationScreen extends StatefulWidget {
  const EditLocationScreen({super.key});

  @override
  State<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  StructuredAddress? _structuredAddress;
  bool _saving = false;

  Future<void> _save() async {
    if (_structuredAddress == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      Map<String, dynamic> data = {
        'exactLocation': _structuredAddress!.toFirestore(),
        'city': _structuredAddress!.city,
        'postalCode': _structuredAddress!.postalCode,
        'country': _structuredAddress!.country,
        'countryCode': _structuredAddress!.countryCode,
        'formattedAddress': _structuredAddress!.formattedAddress,
        'latitude': _structuredAddress!.coordinates.latitude,
        'longitude': _structuredAddress!.coordinates.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('location_updated_success'.tr())));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('edit_address'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use LocationSelectorWidget for GPS + Manual options
            Expanded(
              child: LocationSelectorWidget(
                onAddressComplete: (address) {
                  setState(() {
                    _structuredAddress = address;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_structuredAddress != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _structuredAddress!.formattedAddress,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_structuredAddress!.city}, ${_structuredAddress!.postalCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _structuredAddress == null ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text('save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
