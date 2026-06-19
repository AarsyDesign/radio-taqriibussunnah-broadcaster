import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../theme/app_theme.dart';

class PrimaryLiveButton extends StatelessWidget {
  const PrimaryLiveButton({
    super.key,
    required this.status,
    required this.onStart,
    required this.onStop,
  });

  final ConnectionStatus status;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final isActive =
        status == ConnectionStatus.live ||
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.connectionDropped;

    return SizedBox(
      width: double.infinity,
      height: 68,
      child: FilledButton.icon(
        onPressed: isActive ? onStop : onStart,
        style: FilledButton.styleFrom(
          backgroundColor: isActive ? AppTheme.danger : AppTheme.forest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(
          isActive ? Icons.stop_circle_rounded : Icons.podcasts_rounded,
          size: 28,
        ),
        label: Text(isActive ? 'Stop Siaran' : 'Mulai Siaran'),
      ),
    );
  }
}
