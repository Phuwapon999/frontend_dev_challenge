import 'package:flutter/material.dart';

class ReservationCountdownBadge extends StatelessWidget {
  final DateTime expiresAt;

  const ReservationCountdownBadge({super.key, required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => true),
      builder: (context, snapshot) {
        final duration = expiresAt.difference(DateTime.now());
        if (duration.isNegative) {
          return const Text('Expired', style: TextStyle(color: Colors.red));
        }

        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Reserved: $minutes:$seconds',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        );
      },
    );
  }
}
