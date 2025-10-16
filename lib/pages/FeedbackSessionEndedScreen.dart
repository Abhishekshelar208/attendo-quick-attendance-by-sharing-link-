import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';

class FeedbackSessionEndedScreen extends StatefulWidget {
  final String sessionType; // 'Q&A' or 'Feedback'
  final String sessionName;

  const FeedbackSessionEndedScreen({
    Key? key,
    required this.sessionType,
    required this.sessionName,
  }) : super(key: key);

  @override
  _FeedbackSessionEndedScreenState createState() => _FeedbackSessionEndedScreenState();
}

class _FeedbackSessionEndedScreenState extends State<FeedbackSessionEndedScreen>
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
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ended Icon Animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xffef4444).withValues(alpha: 0.1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xffef4444).withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: Color(0xffef4444),
                        size: 120,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Session Ended Text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Session Ended',
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
                      icon: Icons.timer_off_outlined,
                      title: 'No Longer Accepting Responses',
                      description:
                          'The teacher has closed this session. New submissions are no longer being accepted.',
                      color: const Color(0xffef4444),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInWidget(
                    delay: const Duration(milliseconds: 600),
                    child: _buildInfoCard(
                      icon: Icons.school_outlined,
                      title: 'Contact Your Teacher',
                      description:
                          'If you need to submit a response, please reach out to your teacher directly.',
                      color: const Color(0xfff59e0b),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInWidget(
                    delay: const Duration(milliseconds: 800),
                    child: _buildInfoCard(
                      icon: Icons.access_time_rounded,
                      title: 'Stay Tuned',
                      description:
                          'Your teacher may create new sessions in the future. Keep an eye out for new links!',
                      color: const Color(0xff8b5cf6),
                    ),
                  ),
                ],
              ),
            ),
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
