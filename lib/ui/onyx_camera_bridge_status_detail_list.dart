import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_detail_line.dart';

class OnyxCameraBridgeStatusDetailList extends StatelessWidget {
  final List<OnyxAgentCameraBridgeStatusDetail> fields;
  final Color labelColor;
  final Color valueColor;
  final double bottomPadding;

  const OnyxCameraBridgeStatusDetailList({
    super.key,
    required this.fields,
    required this.labelColor,
    required this.valueColor,
    this.bottomPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          OnyxCameraBridgeDetailLine(
            label: field.label,
            value: field.value,
            labelColor: labelColor,
            valueColor: valueColor,
            bottomPadding: bottomPadding,
          ),
      ],
    );
  }
}
