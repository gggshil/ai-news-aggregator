import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? sessionExpiredMessage;

  const AuthScreen({super.key, this.sessionExpiredMessage});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _serverController = TextEditingController(text: ApiService.defaultBaseUrl);

  // 6 visual OTP digit controllers and focus nodes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _cooldownTimer;
  int _resendCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sessionExpiredMessage != null) {
      _errorMessage = widget.sessionExpiredMessage;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _serverController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    setState(() {
      _resendCooldownSeconds = seconds;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldownSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCooldownSeconds--;
          });
        }
      }
    });
  }

  String get _currentOtp => _otpControllers.map((c) => c.text).join();

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      // Full OTP pasted (e.g., "482913")
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          if (i < digits.length) {
            _otpControllers[i].text = digits[i];
          }
        }
        if (digits.length >= 6) {
          _otpFocusNodes[5].requestFocus();
          _handleVerifyOtp();
        } else {
          _otpFocusNodes[digits.length].requestFocus();
        }
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        if (_currentOtp.length == 6) {
          _handleVerifyOtp();
        }
      }
    }
  }

  Future<void> _handleSendOtp() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = "Please enter a valid email address.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final serverUrl = _serverController.text.trim();
    final result = await ApiService.sendOtp(
      email: email,
      customBaseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      setState(() {
        _isOtpSent = true;
        _errorMessage = null;
      });
      _startCooldown(45);
      // Auto-focus first digit field
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } else {
      setState(() {
        _errorMessage = _formatErrorMessage(result.message);
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_isLoading) return;

    final otp = _currentOtp;
    if (otp.length != 6) {
      setState(() => _errorMessage = "Please enter all 6 digits of the verification code.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final serverUrl = _serverController.text.trim();

    final result = await ApiService.verifyOtp(
      email: email,
      otp: otp,
      customBaseUrl: serverUrl.isNotEmpty ? serverUrl : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Verified successfully!"),
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
                hintText: 'user@gmail.com',
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
            ),
            onPressed: () {
              final val = googleEmailController.text.trim();
              if (val.isNotEmpty && val.contains('@')) {
                Navigator.pop(ctx);
                _processGoogleAuth(val);
              }
            },
            child: const Text('Verify Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

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

  String _formatErrorMessage(String raw) {
    if (raw.contains('MissingPluginException') || raw.contains('PlatformException')) {
      return "Google Sign-In is currently unavailable in this environment. Please use email verification.";
    }
    if (raw.contains('Could not connect') || raw.contains('SocketException')) {
      return "Could not connect to the backend server. Please check your connection.";
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;

            return Column(
              children: [
                _buildTopBar(isDesktop),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 48 : 20,
                        vertical: isDesktop ? 32 : 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column (Editorial Hero)
                                  Expanded(
                                    flex: 12,
                                    child: _buildEditorialHero(),
                                  ),
                                  const SizedBox(width: 64),
                                  // Right Column (Subscription / Auth Panel)
                                  Expanded(
                                    flex: 9,
                                    child: _buildAuthTerminal(),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildEditorialHero(isCompact: true),
                                  const SizedBox(height: 32),
                                  _buildAuthTerminal(),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 16,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: AppLogo(
              size: isDesktop ? 44 : 32,
              showBadge: isDesktop,
              fontSize: isDesktop ? 16 : 13.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 10 : 8,
              vertical: isDesktop ? 5 : 3.5,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.statusLive),
                const SizedBox(width: 5),
                Text(
                  isDesktop ? 'LIVE INGESTION' : 'LIVE',
                  style: const TextStyle(
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

            // Narrative Paragraph
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

        // Bottom Source Tags Row
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

  Widget _buildOtpBox(int index) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[index].text.isEmpty &&
            index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 44,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF090A0E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _otpFocusNodes[index].hasFocus
                ? AppColors.brandPrimary
                : const Color(0xFF1E212D),
            width: _otpFocusNodes[index].hasFocus ? 1.5 : 1.0,
          ),
          boxShadow: _otpFocusNodes[index].hasFocus
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0,
            ),
            decoration: const InputDecoration(
              counterText: "",
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) => _onOtpChanged(index, val),
          ),
        ),
      ),
    );
  }

  /// -------------------------------------------------------------------------
  /// PASSWORDLESS EMAIL OTP AUTHENTICATION TERMINAL
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
            // STEP 1: EMAIL INPUT SCREEN
            if (!_isOtpSent) ...[
              const Text(
                'Get your daily briefing',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Enter your email to receive a 6-digit verification code.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A8F98),
                  height: 1.4,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                ErrorAlert(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // Email Address Input
              InputField(
                label: 'Email address',
                placeholder: 'you@example.com',
                controller: _emailController,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (_) => _handleSendOtp(),
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
              const SizedBox(height: 20),

              // Primary CTA Button: Send Verification Code
              PrimaryButton(
                text: 'Send verification code',
                isLoading: _isLoading,
                showArrow: true,
                onPressed: _handleSendOtp,
              ),
              const SizedBox(height: 18),

              // Divider
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

              // Google OAuth Button
              GoogleButton(
                isLoading: _isLoading,
                onPressed: _handleGoogleSignIn,
              ),
            ]

            // STEP 2: 6-DIGIT OTP VERIFICATION SCREEN
            else ...[
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8F98),
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit verification code to:\n'),
                    TextSpan(
                      text: _emailController.text.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                ErrorAlert(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),

              // 6 Visual Input Boxes Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              const SizedBox(height: 20),

              // Verify & Continue Button
              PrimaryButton(
                text: 'Verify & Continue',
                isLoading: _isLoading,
                showArrow: true,
                onPressed: _handleVerifyOtp,
              ),
              const SizedBox(height: 18),

              // Resend & Change Email Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _resendCooldownSeconds > 0
                      ? Text(
                          'Resend code in ${_resendCooldownSeconds}s',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : InkWell(
                          onTap: _isLoading ? null : _handleSendOtp,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Resend code',
                              style: TextStyle(
                                color: Color(0xFF6875E8),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isOtpSent = false;
                        _errorMessage = null;
                        _clearOtp();
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Change email',
                        style: TextStyle(
                          color: Color(0xFF8A8F98),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

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
