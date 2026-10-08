import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../viewmodels/auth_manager.dart';
import 'home_navigation_screen.dart';

/// Screen allowing community members and staff to register with WildGuard.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final TextEditingController _badgeNumberController;

  String _selectedPark = 'Yala National Park';
  String _selectedRole = 'RANGER';

  final List<String> _nationalParks = [
    'Yala National Park',
    'Wilpattu National Park',
    'Udawalawe National Park',
    'Sinharaja Forest Reserve',
    'Minneriya National Park',
    'Horton Plains National Park',
  ];

  bool _isLoadingBadge = false;

  @override
  void initState() {
    super.initState();
    _badgeNumberController = TextEditingController(
      text: _getAssignedBadgeForRole(_selectedRole),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDynamicBadgeNumber(_selectedRole);
    });
  }

  Future<void> _loadDynamicBadgeNumber(String role) async {
    if (role == 'VILLAGER') {
      setState(() {
        _isLoadingBadge = false;
        _badgeNumberController.clear();
      });
      return;
    }
    setState(() => _isLoadingBadge = true);
    try {
      final authManager = context.read<AuthManager>();
      final serverBadge = await authManager.fetchNextBadgeNumber(role);
      if (mounted && serverBadge.isNotEmpty) {
        _badgeNumberController.text = serverBadge;
      }
    } catch (_) {
      // Retain fallback if network request fails
    } finally {
      if (mounted) {
        setState(() => _isLoadingBadge = false);
      }
    }
  }

  String _getAssignedBadgeForRole(String role) {
    switch (role) {
      case 'MANAGER':
        return 'WG-MGR-001';
      case 'LIAISON':
        return 'WG-LIA-001';
      case 'VILLAGER':
        return '';
      case 'RANGER':
      default:
        return 'WG-RNG-001';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _badgeNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authManager = context.read<AuthManager>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await authManager.register(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      badgeNumber: _selectedRole == 'VILLAGER'
          ? null
          : _badgeNumberController.text,
      assignedPark: _selectedPark,
      role: _selectedRole,
      phoneNumber: _phoneController.text,
    );

    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Account created! Welcome, ${authManager.rangerDisplayName}',
          ),
          backgroundColor: AppColors.greenSyncSuccess,
          duration: const Duration(seconds: 2),
        ),
      );
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeNavigationScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthManager>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header text
                    Text(
                      _selectedRole == 'VILLAGER'
                          ? 'Join Your WildGuard Community'
                          : 'Join WildGuard Conservation Team',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create your official account to access the WildGuard system.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Error Banner
                    if (authManager.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.redOfflineAlert.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.redOfflineAlert.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.redOfflineAlert,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authManager.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.redOfflineAlert,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Full Name
                    TextFormField(
                      key: const Key('reg_fullname_field'),
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    if (_selectedRole == 'VILLAGER') ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number (for response updates)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Username
                    TextFormField(
                      key: const Key('reg_username_field'),
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (val.trim().length < 3) {
                          return 'At least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      key: const Key('reg_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Valid email required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      key: const Key('reg_password_field'),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Password is required';
                        }
                        if (val.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Role Selection Dropdown
                    DropdownButtonFormField<String>(
                      key: const Key('reg_role_field'),
                      initialValue: _selectedRole,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Role *',
                        prefixIcon: const Icon(Icons.security_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'RANGER',
                          child: Text('RANGER (Field Operations)'),
                        ),
                        DropdownMenuItem(
                          value: 'MANAGER',
                          child: Text('MANAGER (Park Administration)'),
                        ),
                        DropdownMenuItem(
                          value: 'LIAISON',
                          child: Text('LIAISON (Community Relations)'),
                        ),
                        DropdownMenuItem(
                          value: 'VILLAGER',
                          child: Text('VILLAGER (Community Member)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRole = val;
                            _badgeNumberController.text =
                                _getAssignedBadgeForRole(val);
                          });
                          _loadDynamicBadgeNumber(val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Assigned Park Dropdown
                    DropdownButtonFormField<String>(
                      key: const Key('reg_park_field'),
                      initialValue: _selectedPark,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Assigned National Park / Sanctuary',
                        prefixIcon: const Icon(Icons.park_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _nationalParks.map((park) {
                        return DropdownMenuItem(value: park, child: Text(park));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPark = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Staff badge numbers are not used for community accounts.
                    if (_selectedRole != 'VILLAGER') ...[
                      TextFormField(
                        key: const Key('reg_badge_field'),
                        controller: _badgeNumberController,
                        readOnly: true,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          letterSpacing: 1.1,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Staff Badge ID (System-Assigned)',
                          helperText: 'Auto-assigned by WildGuard based on selected role',
                          helperStyle: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(Icons.assignment_ind_outlined),
                          suffixIcon: _isLoadingBadge
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Tooltip(
                                  message: 'System-assigned badge number. Cannot be manually edited.',
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F2),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Submit Registration Button
                    ElevatedButton(
                      key: const Key('reg_submit_button'),
                      onPressed: authManager.isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        elevation: 2,
                      ),
                      child: authManager.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.how_to_reg, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'REGISTER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Back to Login Link
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Already have an account? Back to Login',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
