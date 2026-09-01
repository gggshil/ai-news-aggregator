import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/collapsible_settings.dart';
import '../widgets/error_alert.dart';
import '../widgets/feature_item.dart';
import '../widgets/google_button.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import 'success_animation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController(text: 'http://localhost:8000');
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  bool _isRegistering = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _processGoogleAuth(String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final serverUrl = _serverController.text.trim();
    final result = await ApiService.authenticateWithGoogle(
      email: email,
      customBaseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verified Google Account: $email'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessAnimationScreen(email: email),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _showGooglePromptDialog() async {
    final googleEmailController = TextEditingController(
      text: _emailController.text.isNotEmpty ? _emailController.text : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Row(
          children: [
            Icon(Icons.g_mobiledata_rounded, size: 36, color: Color(0xFFEA4335)),
            SizedBox(width: 8),
            Text(
              'Sign in with Google',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm your Google email address to receive daily AI digests without needing a password:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: googleEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'yourname@gmail.com',
                hintStyle: const TextStyle(color: AppColors.textPlaceholder),
                filled: true,
                fillColor: AppColors.surfaceInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryIndigo),
                ),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.accentCyan),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final email = googleEmailController.text.trim();
              if (email.contains('@') && email.contains('.')) {
                Navigator.pop(ctx);
                _processGoogleAuth(email);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await _processGoogleAuth(googleUser.email);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showGooglePromptDialog();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final serverUrl = _serverController.text.trim();

    final result = await ApiService.authenticate(
      email: email,
      password: password,
      isRegistering: _isRegistering,
      customBaseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessAnimationScreen(email: result.email ?? email),
        ),
      );
    } else {
      setState(() {
        _errorMessage = _formatErrorMessage(result.message);
      });
    }
  }

  String _formatErrorMessage(String raw) {
    if (raw.contains('MissingPluginException') || raw.contains('PlatformException')) {
      return "Google Sign-In isn't available in this environment. Please use email and password.";
    }
    if (raw.contains('Could not connect')) {
      return "Could not connect to the backend server. Please verify the server is running.";
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Subtle atmospheric background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.4),
                  radius: 1.2,
                  colors: [
                    Color(0x184F46E5),
                    Color(0x0C0D1320),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, 0.6),
                  radius: 1.0,
                  colors: [
                    Color(0x147C3AED),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.8],
                ),
              ),
            ),
          ),

          // Main Responsive Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;

                if (isDesktop) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1140),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Hero Area
                            Expanded(
                              flex: 11,
                              child: _buildHeroSection(isDesktop: true),
                            ),
                            const SizedBox(width: 64),
                            // Right Auth Card
                            Expanded(
                              flex: 10,
                              child: _buildAuthCard(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // Tablet & Mobile
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          children: [
                            _buildHeroSection(isDesktop: false),
                            const SizedBox(height: 32),
                            _buildAuthCard(),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // App Logo & Brand
        const AppLogo(
          size: 48,
          showText: true,
          subtitle: 'Autonomous Intelligence Digest',
        ),
        const SizedBox(height: 32),

        // Hero Headline
        Text(
          'AI intelligence,\ndelivered every morning.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 38 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),

        // Supporting Subtext
        Text(
          'Stay ahead of the AI curve with a daily intelligence digest curated from OpenAI, Anthropic, Gemini, DeepSeek, and leading research papers.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Feature Highlights
        if (isDesktop) ...[
          const FeatureItem(
            icon: Icons.psychology_outlined,
            title: 'Multi-Agent Curation',
            description: 'Intelligent GPT-4o agents extract key breakthroughs and rank top 10 stories.',
          ),
          const SizedBox(height: 18),
          const FeatureItem(
            icon: Icons.mark_email_read_outlined,
            title: 'Direct to Your Gmail',
            description: 'Automated 24/7 delivery with personalized greeting tailored to your email.',
          ),
          const SizedBox(height: 18),
          const FeatureItem(
            icon: Icons.verified_user_outlined,
            title: 'Zero Noise & Hallucinations',
            description: 'Direct summaries of official releases, research logs, and video transcripts.',
          ),
        ],
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primaryIndigo.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title & Subtitle
            Text(
              _isRegistering ? 'Subscribe to AI News' : 'Welcome back',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isRegistering
                  ? 'Get the most important AI updates delivered to your inbox.'
                  : 'Enter your credentials to manage your subscription.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Error Alert (Dismissible)
            if (_errorMessage != null)
              ErrorAlert(
                message: _errorMessage!,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Email Address Input
            InputField(
              label: 'Email address',
              placeholder: 'you@gmail.com',
              controller: _emailController,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password Input
            InputField(
              label: 'Password',
              placeholder: 'Enter your password',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter your password';
                }
                if (val.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Primary Submit Button
            PrimaryButton(
              text: _isRegistering ? 'Subscribe for AI News' : 'Log In',
              isLoading: _isLoading,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 20),

            // OR Divider
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.borderSubtle)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.0),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.borderSubtle)),
              ],
            ),
            const SizedBox(height: 20),

            // Google Sign-In Button
            GoogleButton(
              isLoading: _isLoading,
              onPressed: _handleGoogleSignIn,
            ),
            const SizedBox(height: 24),

            // Toggle Between Sign Up and Log In
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isRegistering ? 'Already subscribed?' : "Don't have an account?",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                      _errorMessage = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      _isRegistering ? 'Log In' : 'Subscribe Now',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Collapsible Backend Server Settings
            Center(
              child: CollapsibleSettings(
                serverController: _serverController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
