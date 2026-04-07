import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OperatorStreamEmbedView extends StatelessWidget {
  final Uri uri;

  const OperatorStreamEmbedView({
    super.key,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F8FC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        'Inline stream embedding is only available in the Flutter web build. Use the browser player URL for direct operator viewing.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: const Color(0xFF556B80),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}
