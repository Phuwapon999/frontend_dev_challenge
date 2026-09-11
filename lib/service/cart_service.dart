import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  Timer? _expirationTimer;

  @override
  void onInit() {
    super.onInit();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _removeExpiredFlashDeals();
    });
  }

  @override
  void onClose() {
    _expirationTimer?.cancel();
    super.onClose();
  }

  void _removeExpiredFlashDeals() {
    if (items.isEmpty) return;

    final now = DateTime.now();

    final expiredItems = items.where((item) {
      final endsAt = item.deal.flashSaleEndsAt;
      return endsAt != null && endsAt.isBefore(now);
    }).toList();

    if (expiredItems.isNotEmpty) {
      for (var expired in expiredItems) {
        items.removeWhere((i) => i.deal.id == expired.deal.id);

        Get.snackbar(
          'Flash Sale Expired',
          '${expired.deal.name} was removed from your bag.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(12),
        );
      }
      _recount();
    }
  }

  void add(DealModel deal) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
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
