import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            onPressed: () {
              // TODO: Implement date range selector
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_rounded,
                  size: 80,
                  color: ThemeHelper.getTextTertiary(context),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Data Available',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create attendance sessions to\nview analytics and insights',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
