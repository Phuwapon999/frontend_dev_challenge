import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:get/get.dart';

import '../../service/analytics_service.dart'; // ปรับ path ตามจริง

class DealImpressionTracker extends StatefulWidget {
  final int dealId;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _timer;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _tracked = Get.find<AnalyticsService>().hasSeen(widget.dealId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tracked) return widget.child;

    return VisibilityDetector(
      key: Key('impression_${widget.source}_${widget.dealId}'),
      onVisibilityChanged: (info) {
        if (_tracked) return;
        if (info.visibleFraction >= 0.5) {
          if (_timer == null || !_timer!.isActive) {
            _timer = Timer(const Duration(seconds: 1), () {
              _tracked = true;
              Get.find<AnalyticsService>().logDealImpression(
                dealId: widget.dealId,
                source: widget.source,
                position: widget.position,
              );
            });
          }
        } else {
          _timer?.cancel();
          _timer = null;
        }
      },
      child: widget.child,
    );
  }
}
