import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ThemeHelper.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Teacher',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'teacher@example.com',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Settings Section
              _buildSectionTitle(context, 'Settings'),
              const SizedBox(height: 16),
              _buildSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (value) {
                      // TODO: Implement theme toggle
                    },
                  ),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      // TODO: Implement notifications toggle
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // About Section
              _buildSectionTitle(context, 'About'),
              const SizedBox(height: 16),
              _buildSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.info_rounded,
                  title: 'App Version',
                  subtitle: '1.0.0',
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.description_rounded,
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
              ]),
              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement sign out
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getErrorColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ThemeHelper.getTextPrimary(context),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getShadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ThemeHelper.getPrimaryColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: ThemeHelper.getPrimaryColor(context),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ThemeHelper.getTextPrimary(context),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ThemeHelper.getTextSecondary(context),
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
