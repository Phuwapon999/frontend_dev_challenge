import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;
    isCheckingOut.value = true;

    try {
      final now = DateTime.now();
      final validItems = cartService.items.where((i) {
        final isResExpired = i.expiresAt != null && i.expiresAt!.isBefore(now);
        final isFlashExpired = i.deal.flashSaleEndsAt != null &&
            i.deal.flashSaleEndsAt!.isBefore(now);

        return !isResExpired && !isFlashExpired;
      }).toList();

      if (validItems.isEmpty) {
        isCheckingOut.value = false;
        return;
      }

      final order = await orderRepo.checkout(validItems);

      for (var item in validItems) {
        cartService.items.removeWhere((i) => i.deal.id == item.deal.id);
      }

      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);

      if (e.message.contains('410') ||
          e.message.toLowerCase().contains('expired')) {
        Get.snackbar(
          'Checkout failed',
          'The reservation time for some items has expired. Please review your cart again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.red.shade900,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Checkout failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
    isCheckingOut.value = false;
  }
}
