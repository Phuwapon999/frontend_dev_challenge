import 'package:flutter/material.dart';

class FlashDealsSectionController extends StatelessWidget {
  final DateTime endsAt;

  const FlashDealsSectionController({super.key, required this.endsAt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final timeLeft = endsAt.difference(now);
        final isExpired = timeLeft.isNegative;

        String formatDuration(Duration d) {
          if (d.isNegative) return 'Expired';
          String twoDigits(int n) => n.toString().padLeft(2, '0');
          String minutes = twoDigits(d.inMinutes.remainder(60));
          String seconds = twoDigits(d.inSeconds.remainder(60));
          if (d.inHours > 0) {
            return '${twoDigits(d.inHours)}:$minutes:$seconds';
          }
          return '$minutes:$seconds';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isExpired ? Colors.grey.shade200 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            formatDuration(timeLeft),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isExpired ? Colors.grey.shade600 : Colors.red.shade700,
            ),
          ),
        );
      },
    );
  }
}
