import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/services/auth_service.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/pages/home_screen_with_nav.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        // Show success message
        EnhancedSnackBar.show(
          context,
          message: 'Welcome ${userCredential.user?.displayName ?? "User"}! 🎉',
          type: SnackBarType.success,
        );
        
        // Navigate to home screen
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreenWithNav()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        EnhancedSnackBar.show(
          context,
          message: 'Sign in failed. Please try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Animation
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: ThemeHelper.getPrimaryGradient(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 48),

                  // App Name
                  Text(
                    'QuickPro',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            ThemeHelper.getPrimaryColor(context),
                            ThemeHelper.getSecondaryColor(context),
                          ],
                        ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Smart Attendance & Event Management',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: ThemeHelper.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 64),

                  // Welcome Message
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ThemeHelper.getBorderColor(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeHelper.getShadowColor(context),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.waving_hand_rounded,
                          size: 48,
                          color: Colors.amber,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Welcome!',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sign in to manage your events and attendance seamlessly',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 3,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: ThemeHelper.getBorderColor(context),
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeHelper.getPrimaryColor(context),
                                ),
                              ),
                            )
                          : Text(
                              'Sign in with Google',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Features
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFeatureChip(Icons.history_rounded, 'Activity History'),
                      _buildFeatureChip(Icons.cloud_sync_rounded, 'Cloud Sync'),
                      _buildFeatureChip(Icons.security_rounded, 'Secure'),
                    ],
                  ),
                  SizedBox(height: 40),

                  // Privacy Note
                  Text(
                    'We only access your name and email',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ThemeHelper.getTextTertiary(context),
                      fontStyle: FontStyle.italic,
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

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: ThemeHelper.getPrimaryColor(context),
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.getPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
