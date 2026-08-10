import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordsMatch = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset_password'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'reset_note'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: 'new_password'.tr(),
                hintText: 'enter_new_password'.tr(),
                obscureText: true,
                controller: _newPasswordController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'please_enter_new_password'.tr();
                  }
                  if (value.length < 8) {
                    return 'password_8_char'.tr();
                  }
                  return null;
                },
                onChanged: (_) => _checkPasswordsMatch(), prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 8),
              Text(
                'min_8_char'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'confirm_password'.tr(),
                hintText: 'confirm_new_password'.tr(),
                obscureText: true,
                controller: _confirmPasswordController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'please_confirm_password'.tr();
                  }
                  if (!_passwordsMatch) {
                    return 'passwords_do_not_match'.tr();
                  }
                  return null;
                },
                onChanged: (_) => _checkPasswordsMatch(), prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 8),
              Text(
                _passwordsMatch ? '' : 'both_passwords_must_match'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 32),
              AuthButton(
                text: 'reset_password'.tr(),
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkPasswordsMatch() {
    setState(() {
      _passwordsMatch =
          _newPasswordController.text == _confirmPasswordController.text;
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _passwordsMatch) {
      setState(() => _isLoading = true);
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('password_changed'.tr()),
        content: Text('password_change_success'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}