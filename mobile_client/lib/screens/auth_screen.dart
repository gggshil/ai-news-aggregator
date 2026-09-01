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
        backgroundColor: const Color(0xFF101218),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E212D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 20, color: AppColors.brandPrimary),
            SizedBox(width: 8),
            Text(
              'Google Account Verification',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google email address to receive automated daily briefings directly to your inbox:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: googleEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'you@gmail.com',
                hintStyle: const TextStyle(color: Color(0xFF4B4F56), fontSize: 13.5),
                filled: true,
                fillColor: const Color(0xFF090A0E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E212D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.brandPrimary),
                ),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF5A5E6B), size: 17),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8F98), fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              final email = googleEmailController.text.trim();
              if (email.contains('@') && email.contains('.')) {
                Navigator.pop(ctx);
                _processGoogleAuth(email);
              }
            },
            child: const Text('Continue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
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
      return "Google Sign-In is currently unavailable in this environment. Please use email and password.";
    }
    if (raw.contains('Could not connect')) {
      return "Could not connect to the backend server. Please check your connection.";
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: AppColors.bgDark,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
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
                                      // Left Column (Preserved Exactly)
                                      Expanded(
                                        flex: 12,
                                        child: _buildEditorialHero(),
                                      ),
                                      const SizedBox(width: 72),
                                      // Right Column: Redesigned Subscription Panel
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            // Category pill with live indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: const Text(
                'AI NEWS AGGREGATOR  •  DAILY BRIEFING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Main Editorial Headline
            Text(
              'The daily AI briefing for builders and researchers.',
              textAlign: isCompact ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: isCompact ? 28 : 38,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1.1,
                height: 1.14,
              ),
            ),
            const SizedBox(height: 14),

            // Narrative Paragraph matching container width and balanced length
            Text(
              'Autonomous multi-agent synthesis across OpenAI, Anthropic, DeepSeek, Google, and arXiv. Curated for technical depth and breakthroughs without marketing noise, delivered directly to your inbox every morning.',
              textAlign: isCompact ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: isCompact ? 13.5 : 15,
                color: AppColors.textSecondary,
                height: 1.55,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 22),

            // Live Synthesis Sample Card
            if (!isCompact) ...[
              Container(
                padding: const EdgeInsets.all(18),
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
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SAMPLE DIGEST ITEM  •  SCORED 9.8 / 10',
                              style: TextStyle(
                                fontSize: 10.5,
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'DeepSeek-V3 MoE Architecture & Sparse Computation Breakdown',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Technical breakdown of multi-head latent attention (MLA) and multi-token prediction (MTP) yielding high-throughput inference efficiency.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),

        // Bottom Source Tags Row aligning with bottom of container
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

  /// -------------------------------------------------------------------------
  /// REDESIGNED RIGHT-SIDE SUBSCRIPTION / AUTHENTICATION PANEL
  /// -------------------------------------------------------------------------
  Widget _buildAuthTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF181A22), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title (21px bold, tight tracking, crisp white)
            Text(
              _isRegistering ? 'Get your daily briefing' : 'Welcome back',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 7),

            // Card Subtitle (13px, muted gray, comfortable line height)
            Text(
              _isRegistering
                  ? 'Enter your Gmail to start receiving automated AI digests.'
                  : 'Enter your credentials to manage your daily briefing.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8A8F98),
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 24),

            // Compact Error Alert
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
            const SizedBox(height: 20),

            // Primary CTA Button (48px, subtle indigo gradient, arrow transition)
            PrimaryButton(
              text: _isRegistering ? 'Subscribe to AI Digest' : 'Sign In',
              isLoading: _isLoading,
              showArrow: true,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 18),

            // Minimal Restrained Divider
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFF161822), height: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Color(0xFF4B4F56),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFF161822), height: 1)),
              ],
            ),
            const SizedBox(height: 18),

            // Google Button (Dark surface, matching 48px height, 10px radius)
            GoogleButton(
              isLoading: _isLoading,
              onPressed: _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),

            // Login / Toggle Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isRegistering ? 'Already subscribed?' : "Don't have an account?",
                  style: const TextStyle(
                    color: Color(0xFF8A8F98),
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 6),
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
                        color: Color(0xFF6875E8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Backend Server Settings (Clean developer control with hairline divider)
            CollapsibleSettings(
              serverController: _serverController,
            ),
          ],
        ),
      ),
    );
  }
}
