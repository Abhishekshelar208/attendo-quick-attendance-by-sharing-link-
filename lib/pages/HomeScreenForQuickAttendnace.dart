import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'CreateAttendanceScreen.dart';

class HomeScreenForQuickAttendnace extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "QuickPro",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Illustration/Icon
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.checklist_rounded,
                    size: 100,
                    color: Color(0xFF6366F1),
                  ),
                ),
                SizedBox(height: 40),

                // Welcome Text
                Text(
                  "Welcome to QuickPro",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "Simplify your attendance tracking\nwith our easy-to-use system",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),

                // Create Attendance Button
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 400),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateAttendanceScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.add_rounded, size: 24),
                    label: Text(
                      "Create Attendance Session",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Features List
                Container(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFeatureItem(
                            Icons.speed_rounded,
                            "Quick Setup",
                            "Create sessions in seconds",
                          ),
                          SizedBox(height: 16),
                          _buildFeatureItem(
                            Icons.share_rounded,
                            "Easy Sharing",
                            "Share links with students",
                          ),
                          SizedBox(height: 16),
                          _buildFeatureItem(
                            Icons.cloud_done_rounded,
                            "Real-time Sync",
                            "Instant attendance updates",
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
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(0xFF6366F1),
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
