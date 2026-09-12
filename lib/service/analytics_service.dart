import 'dart:async';

import 'package:get/get.dart';
import 'package:rescu/service/fake_api_service.dart';

import '../util/log_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// The "Impression tracking" feature task builds on top of this service.
class AnalyticsService extends GetxService {
  final events = <AnalyticsEvent>[].obs;

  final _seenDealIds = <int>{};
  final _batchQueue = <Map<String, dynamic>>[];
  Timer? _batchTimer;

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  bool hasSeen(int dealId) => _seenDealIds.contains(dealId);

  void logDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (_seenDealIds.contains(dealId)) return;
    _seenDealIds.add(dealId);

    final properties = {
      'deal_id': dealId,
      'source': source,
      'position': position,
    };

    logEvent('deal_impression', properties);
    _batchQueue.add({
      'event': 'deal_impression',
      ...properties,
    });

    if (_batchQueue.length == 1) {
      _batchTimer = Timer(const Duration(seconds: 15), _flushBatch);
    }

    if (_batchQueue.length >= 10) {
      _flushBatch();
    }
  }

  void _flushBatch() {
    _batchTimer?.cancel();
    if (_batchQueue.isEmpty) return;
    Get.find<FakeApiService>().sendAnalyticsBatch(List.from(_batchQueue));
    _batchQueue.clear();
  }
}
