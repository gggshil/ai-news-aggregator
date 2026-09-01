import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class SuccessAnimationScreen extends StatefulWidget {
  final String email;

  const SuccessAnimationScreen({super.key, required this.email});

  @override
  State<SuccessAnimationScreen> createState() => _SuccessAnimationScreenState();
}

class _SuccessAnimationScreenState extends State<SuccessAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              // Top Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'AI PIPELINE CONNECTED',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Central Futuristic Animated Graphic
              Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Glowing Radar Waves
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 250 * _scaleAnimation.value,
                            height: 250 * _scaleAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF6366F1).withValues(alpha: 0.25),
                                  const Color(0xFF38BDF8).withValues(alpha: 0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Orbiting Particles & Data Beams
                      AnimatedBuilder(
                        animation: _orbitController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(220, 220),
                            painter: OrbitPainter(
                              orbitProgress: _orbitController.value,
                              particleProgress: _particleController.value,
                            ),
                          );
                        },
                      ),

                      // Orbiting Source Icons
                      AnimatedBuilder(
                        animation: _orbitController,
                        builder: (context, child) {
                          final angle = _orbitController.value * 2 * math.pi;
                          final x = math.cos(angle) * 85;
                          final y = math.sin(angle) * 85;
                          return Transform.translate(
                            offset: Offset(x, y),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF38BDF8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFF38BDF8),
                                size: 16,
                              ),
                            ),
                          );
                        },
                      ),

                      // Center AI Glowing Core
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                                  blurRadius: 28 * _scaleAnimation.value,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Title & Info Details
              const Text(
                'AI News Delivery Active',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Latest AI breakthroughs are scraped, summarized, and automatically dispatched to:\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Information Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  ),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Daily AI Digest generation automated',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, color: Color(0xFF6366F1), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tracking OpenAI, Anthropic, Gemini, xAI, DeepSeek',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Proceed Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(email: widget.email),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Live AI Feeds',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class OrbitPainter extends CustomPainter {
  final double orbitProgress;
  final double particleProgress;

  OrbitPainter({required this.orbitProgress, required this.particleProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Orbit rings
    final ringPaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius * 0.8, ringPaint);
    canvas.drawCircle(center, radius * 0.55, ringPaint..color = const Color(0xFF38BDF8).withValues(alpha: 0.2));

    // Particle beams moving into center
    final particlePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final baseAngle = (i * math.pi / 2) + (orbitProgress * 2 * math.pi);
      final currentRadius = (radius * 0.8) * (1 - ((particleProgress + (i * 0.25)) % 1.0));
      final px = center.dx + math.cos(baseAngle) * currentRadius;
      final py = center.dy + math.sin(baseAngle) * currentRadius;

      canvas.drawCircle(Offset(px, py), 3.0, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) => true;
}
