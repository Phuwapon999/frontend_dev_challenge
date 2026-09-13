import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

enum DealLoadState { loading, ready, error }

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  late final DealModel deal;

  final loadState = DealLoadState.loading.obs;
  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is DealModel) {
      // มาจาก home feed — มีอ็อบเจกต์อยู่ในมือแล้ว ไม่ต้องยิง network
      _onDealReady(args);
    } else {
      // มาจาก deep link (หรือ route ใดๆ ที่ไม่มี arguments) — มีแค่ id
      // จึงต้อง fetch ดีลก่อนที่จะ render อะไรก็ตามที่แตะ `deal`
      _loadFromDeepLink();
    }
  }

  Future<void> _loadFromDeepLink() async {
    final rawId = Get.parameters['id'];
    final id = rawId != null ? int.tryParse(rawId) : null;

    if (id == null) {
      LogService.error('deep link missing/invalid deal id: $rawId', null);
      loadState.value = DealLoadState.error;
      return;
    }

    try {
      final fetched = await dealRepo.fetchById(id);
      _onDealReady(fetched);
    } catch (e) {
      LogService.error('failed to load deal $id from deep link', e);
      loadState.value = DealLoadState.error;
    }
  }

  void _onDealReady(DealModel d) {
    deal = d;
    _quantityLeft.value = d.quantityLeft;
    analytics.logEvent('deal_details_view', {
      'deal_id': d.id,
      'source': Get.parameters['source'] ?? 'unknown',
    });
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
    loadState.value = DealLoadState.ready;
  }

  Future<void> retry() async {
    if (loadState.value != DealLoadState.error) return;
    loadState.value = DealLoadState.loading;
    await _loadFromDeepLink();
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    LogService.log('re-checking availability for deal ${deal.id}');
    final fresh = await dealRepo.fetchById(deal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    final existingItem =
        cartService.items.firstWhereOrNull((i) => i.deal.id == deal.id);
    final currentQty = existingItem?.quantity ?? 0;

    if (currentQty >= (_quantityLeft.value ?? 0)) {
      Get.snackbar(
        'Maximum quantity reached',
        'You have added all available stock for this item to your bag.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    cartService.add(deal);
    Get.snackbar(
      'Added to bag',
      '${deal.name} — pick up ${deal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
