import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_status_detail_list.dart';

class OnyxCameraBridgeStatusMetadataBlock extends StatelessWidget {
  final List<OnyxAgentCameraBridgeStatusDetail> fields;
  final Color labelColor;
  final Color valueColor;
  final double fieldBottomPadding;
  final String detail;
  final TextStyle detailStyle;
  final double detailTopSpacing;

  const OnyxCameraBridgeStatusMetadataBlock({
    super.key,
    required this.fields,
    required this.labelColor,
    required this.valueColor,
    required this.detail,
    required this.detailStyle,
    this.fieldBottomPadding = 8,
    this.detailTopSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnyxCameraBridgeStatusDetailList(
          fields: fields,
          labelColor: labelColor,
          valueColor: valueColor,
          bottomPadding: fieldBottomPadding,
        ),
        SizedBox(height: detailTopSpacing),
        Text(detail, style: detailStyle),
      ],
    );
  }
}
