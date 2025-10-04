import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              // TODO: Implement filter
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
                  Icons.history_rounded,
                  size: 80,
                  color: ThemeHelper.getTextTertiary(context),
                ),
                const SizedBox(height: 24),
                Text(
                  'No History Yet',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your attendance session history\nwill appear here',
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
