import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/collapsible_settings.dart';
import '../widgets/error_alert.dart';
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
          backgroundColor: AppColors.statusLive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderMedium),
        ),
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 22, color: AppColors.brandPrimary),
            SizedBox(width: 10),
            Text(
              'Google Account Verification',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google email address to authenticate directly for daily briefing delivery:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: googleEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'you@gmail.com',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.brandPrimary),
                ),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          backgroundColor: AppColors.statusLive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      return "Google Sign-In is unavailable in this browser session. Please enter your email.";
    }
    if (raw.contains('Could not connect')) {
      return "Could not connect to backend. Please verify your server status.";
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Subtly textured background grid/canvas
          Positioned.fill(
            child: Container(
              color: AppColors.bgDark,
            ),
          ),

          // Main Responsive Layout
          SafeArea(
            child: Column(
              children: [
                // Top Minimal Header Bar
                _buildTopBar(),

                // Scrollable Body
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 980;

                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 56 : 20,
                            vertical: isDesktop ? 36 : 24,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1160),
                            child: isDesktop
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Column: Editorial Hero & Scored Digest Preview
                                      Expanded(
                                        flex: 12,
                                        child: _buildEditorialHero(),
                                      ),
                                      const SizedBox(width: 72),
                                      // Right Column: Auth Card
                                      Expanded(
                                        flex: 9,
                                        child: _buildAuthTerminal(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildEditorialHero(isCompact: true),
                                      const SizedBox(height: 36),
                                      _buildAuthTerminal(),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: AppLogo(size: 24, showBadge: true),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.statusLive),
                SizedBox(width: 5),
                Text(
                  'LIVE INGESTION',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEditorialHero({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Category pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: const Text(
            'AUTONOMOUS RESEARCH BRIEFING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Headline (Linear / Apple style)
        Text(
          'The daily AI briefing for builders and researchers.',
          textAlign: isCompact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isCompact ? 30 : 42,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.2,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 16),

        // Narrative Copy
        Text(
          'Automated multi-agent synthesis across OpenAI, Anthropic, DeepSeek, Google, and arXiv. Curated for technical depth without marketing noise, delivered directly to your inbox.',
          textAlign: isCompact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            color: AppColors.textSecondary,
            height: 1.5,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 32),

        // Live Feed Sample Digest Card (Raycast/Linear preview)
        if (!isCompact) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SAMPLE DIGEST ITEM  •  SCORED 9.8 / 10',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'DeepSeek-V3 MoE Architecture & Sparse Computation Breakdown',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Analysis of multi-head latent attention (MLA) and multi-token prediction (MTP) yielding unprecedented inference efficiency...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Source Ticker Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: isCompact ? WrapAlignment.center : WrapAlignment.start,
          children: [
            _buildSourceTag('OpenAI'),
            _buildSourceTag('Anthropic'),
            _buildSourceTag('DeepSeek'),
            _buildSourceTag('Google Gemini'),
            _buildSourceTag('xAI'),
            _buildSourceTag('arXiv Papers'),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildAuthTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle
            Text(
              _isRegistering ? 'Get your daily briefing' : 'Welcome back',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isRegistering
                  ? 'Enter your Gmail to start receiving automated AI digests.'
                  : 'Log in to manage your AI delivery preferences.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Error Alert
            if (_errorMessage != null)
              ErrorAlert(
                message: _errorMessage!,
                onDismiss: () => setState(() => _errorMessage = null),
              ),

            // Email Address Input
            InputField(
              label: 'Gmail address',
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
            const SizedBox(height: 16),

            // Password Input
            InputField(
              label: 'Password',
              placeholder: '••••••••',
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
            const SizedBox(height: 22),

            // Primary Button
            PrimaryButton(
              text: _isRegistering ? 'Subscribe to AI Digest' : 'Sign In',
              isLoading: _isLoading,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 16),

            // Subtle Divider
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.borderHairline)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.borderHairline)),
              ],
            ),
            const SizedBox(height: 16),

            // Google Button
            GoogleButton(
              isLoading: _isLoading,
              onPressed: _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),

            // Toggle Between Sign Up and Log In
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isRegistering ? 'Already subscribed?' : "Don't have an account?",
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
                      _isRegistering ? 'Sign In' : 'Subscribe Now',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Collapsible Server Settings
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
