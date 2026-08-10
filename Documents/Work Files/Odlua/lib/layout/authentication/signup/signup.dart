import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/layout/authentication/signup/widgets/signup_form.dart';
import 'package:odlua/layout/authentication/signup/widgets/signup_header.dart';
import 'package:odlua/layout/authentication/widgets/auth_widgets.dart';
import '../login/login.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SignupHeader(),
                  const SizedBox(height: 32),
                  const SignupForm(),
                  const SizedBox(height: 24),
                  // const LoginDivider(),
                  // const SizedBox(height: 16),
                  // const LoginFooter(),
                  // const SizedBox(height: 14),
                  AuthFooter(
                    text: 'already_have_account'.tr(),
                    actionText: 'sign_in'.tr(),
                    onActionPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
