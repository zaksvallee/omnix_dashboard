import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnyxCameraBridgeDetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double bottomPadding;

  const OnyxCameraBridgeDetailLine({
    super.key,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    this.bottomPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: labelColor,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: valueColor,
                fontSize: 10.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
