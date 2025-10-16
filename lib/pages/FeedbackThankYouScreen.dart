import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';

class FeedbackThankYouScreen extends StatefulWidget {
  final String sessionType; // 'Q&A' or 'Feedback'
  final String sessionName;

  const FeedbackThankYouScreen({
    Key? key,
    required this.sessionType,
    required this.sessionName,
  }) : super(key: key);

  @override
  _FeedbackThankYouScreenState createState() => _FeedbackThankYouScreenState();
}

class _FeedbackThankYouScreenState extends State<FeedbackThankYouScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color typeColor = widget.sessionType == 'Q&A'
        ? const Color(0xff3b82f6)
        : const Color(0xff059669);
    
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Success Animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow circle
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: typeColor.withValues(alpha: 0.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: typeColor.withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                              // Main circle with checkmark
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: typeColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: typeColor.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 90,
                                    weight: 700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Thank You Text
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Thank You!',
                                style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  widget.sessionName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Info Cards
                        FadeInWidget(
                          delay: const Duration(milliseconds: 400),
                          child: _buildInfoCard(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Response Submitted',
                            description:
                                'Your response has been successfully recorded and stored securely.',
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInWidget(
                          delay: const Duration(milliseconds: 600),
                          child: _buildInfoCard(
                            icon: Icons.lock_outline_rounded,
                            title: 'Safely Stored',
                            description:
                                'Your data is encrypted and will only be accessible to your teacher.',
                            color: const Color(0xff8b5cf6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInWidget(
                          delay: const Duration(milliseconds: 800),
                          child: _buildInfoCard(
                            icon: Icons.favorite_outline_rounded,
                            title: 'We Appreciate You',
                            description:
                                'Your feedback helps improve the learning experience for everyone.',
                            color: const Color(0xffec4899),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: ThemeHelper.getTextSecondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
