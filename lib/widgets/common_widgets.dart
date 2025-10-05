import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';

/// Beautiful loading indicator
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool showMessage;
  
  const LoadingIndicator({
    Key? key,
    this.message,
    this.showMessage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeHelper.getPrimaryColor(context),
            ),
            strokeWidth: 3,
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: ThemeHelper.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen loading with backdrop
class FullScreenLoading extends StatelessWidget {
  final String? message;
  
  const FullScreenLoading({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ThemeHelper.getPrimaryColor(context),
                  ),
                  strokeWidth: 3,
                ),
                if (message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    message!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state widget
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  
  const ErrorStateWidget({
    Key? key,
    this.title = 'Oops!',
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleInWidget(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeHelper.getErrorColor(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: ThemeHelper.getErrorColor(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FadeInWidget(
              delay: const Duration(milliseconds: 300),
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              SlideInWidget(
                delay: const Duration(milliseconds: 400),
                begin: const Offset(0, 0.2),
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  
  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.onAction,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleInWidget(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeHelper.getPrimaryColor(context).withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: ThemeHelper.getTextTertiary(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FadeInWidget(
              delay: const Duration(milliseconds: 300),
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 32),
              SlideInWidget(
                delay: const Duration(milliseconds: 400),
                begin: const Offset(0, 0.2),
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Enhanced snackbar
class EnhancedSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case SnackBarType.success:
        backgroundColor = ThemeHelper.getSuccessColor(context);
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = ThemeHelper.getErrorColor(context);
        icon = Icons.error_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = ThemeHelper.getWarningColor(context);
        icon = Icons.warning_rounded;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = ThemeHelper.getPrimaryColor(context);
        icon = Icons.info_rounded;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}

enum SnackBarType { success, error, warning, info }

/// Smooth page transition
class SmoothPageRoute extends PageRouteBuilder {
  final Widget page;
  
  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            
            var offsetAnimation = animation.drive(tween);
            var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );
            
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Fade page transition
class FadePageRoute extends PageRouteBuilder {
  final Widget page;
  
  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

/// Pull to refresh wrapper
class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  
  const PullToRefreshWrapper({
    Key? key,
    required this.child,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ThemeHelper.getPrimaryColor(context),
      backgroundColor: ThemeHelper.getCardColor(context),
      child: child,
    );
  }
}

/// Skeleton loader for cards
class SkeletonCard extends StatelessWidget {
  final double? height;
  final EdgeInsets? margin;
  
  const SkeletonCard({
    Key? key,
    this.height,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 120,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading(
                      width: double.infinity,
                      height: 16,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading(
                      width: 150,
                      height: 14,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          ShimmerLoading(
            width: double.infinity,
            height: 12,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}
