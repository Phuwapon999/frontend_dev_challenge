import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/service/fake_api_service.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

class CartItem {
  final DealModel deal;
  int quantity;
  String? reservationId;
  DateTime? expiresAt;

  CartItem({
    required this.deal,
    this.quantity = 1,
    this.reservationId,
    this.expiresAt,
  });
}

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final FakeApiService _api = Get.find<FakeApiService>();
  final itemCount = 0.obs;
  final Set<int> _notifiedExpiredDeals = {};
  Timer? _expirationTimer;

  @override
  void onInit() {
    super.onInit();
    _startExpirationTimer();
  }

  @override
  void onClose() {
    _expirationTimer?.cancel();
    super.onClose();
  }

  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      var needsRefresh = false;

      for (var item in items) {
        final isResExpired =
            item.expiresAt != null && item.expiresAt!.isBefore(now);
        final isFlashExpired = item.deal.flashSaleEndsAt != null &&
            item.deal.flashSaleEndsAt!.isBefore(now);

        if ((isResExpired || isFlashExpired) &&
            !_notifiedExpiredDeals.contains(item.deal.id)) {
          _notifiedExpiredDeals.add(item.deal.id);

          final reason =
              isFlashExpired ? 'Flash Sale period' : 'Reservation time';
          Get.snackbar(
            'Item Expired',
            '$reason for ${item.deal.name} has ended. Please remove it from your cart.',
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade900,
          );
          needsRefresh = true;
        }
      }

      if (needsRefresh) items.refresh();
    });
  }

  Future<void> add(DealModel deal) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        Get.snackbar(
          'Maximum quantity reached',
          'You have added all available stock for this item.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.red.shade900,
        );
        return;
      }
      existing.quantity++;
      items.refresh();
      _recount();
      return;
    }

    final newItem = CartItemModel(deal: deal, quantity: 1);
    items.add(newItem);
    _recount();

    try {
      final Map<String, dynamic> res = await _api.reserveDeal(deal.id);

      final index = items.indexWhere((i) => i.deal.id == deal.id);
      if (index != -1) {
        items[index].reservationId = res['reservationId'] ?? res['id'];
        items[index].expiresAt = DateTime.now().add(const Duration(minutes: 5));
        items.refresh();
      }
    } catch (e) {
      items.removeWhere((i) => i.deal.id == deal.id);
      _recount();
      Get.snackbar('Item Unavailable',
          'Sorry, this item has just been reserved or is out of stock.');
    }
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    existing.quantity--;
    if (existing.quantity <= 0) {
      remove(dealId);
    } else {
      items.refresh();
      _recount();
    }
  }

  Future<void> remove(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);

    if (existing != null && existing.reservationId != null) {
      try {
        await _api.releaseReservation(existing.reservationId!);
      } catch (e) {
        LogService.error('Failed to release reservation', e);
      }
    }

    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
