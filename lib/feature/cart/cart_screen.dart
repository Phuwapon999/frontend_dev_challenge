import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../shared_widget/the_network_image.dart';
import 'cart_controller.dart';
import 'widget/reservation_countdown_badge.dart';

class CartScreen extends GetView<CartController> {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = controller.cartService;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
          title: const Text('My bag'),
          backgroundColor: Colors.white,
          elevation: 0),
      body: Obx(() {
        if (cart.items.isEmpty) {
          return const Center(child: Text('Your bag is empty'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cart.items.length + 1,
          itemBuilder: (context, index) {
            if (index == cart.items.length) {
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              color: Colors.green.shade900, fontSize: 12),
                          children: const [
                            TextSpan(
                                text: 'Environmental Impact: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(
                                text:
                                    "You're saving delicious surplus meals from being wasted today!"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final item = cart.items[index];
            final now = DateTime.now();
            final isResExpired =
                item.expiresAt != null && item.expiresAt!.isBefore(now);
            final isFlashExpired = item.deal.flashSaleEndsAt != null &&
                item.deal.flashSaleEndsAt!.isBefore(now);
            final isExpired = isResExpired || isFlashExpired;
            final isFlashSale = item.deal.flashSaleEndsAt != null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: isExpired ? Colors.red.shade100 : Colors.transparent,
                    width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Opacity(
                                opacity: isExpired ? 0.6 : 1.0,
                                child: TheNetworkImage(
                                  url: item.deal.imageUrl,
                                  width: 64,
                                  height: 64,
                                ),
                              ),
                              if (isExpired)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.red,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: const Text(
                                      'EXPIRED',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.deal.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isExpired
                                          ? Colors.grey.shade500
                                          : Colors.black87)),
                              Text(item.deal.storeName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (isFlashSale)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Text('Flash Sale',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade400)),
                                    ),
                                  if (isExpired)
                                    Text('Reservation ended',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade400))
                                  else if (item.expiresAt != null)
                                    ReservationCountdownBadge(
                                        expiresAt: item.expiresAt!),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isExpired)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade300, size: 20),
                            onPressed: () => cart.remove(item.deal.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isExpired) ...[
                          Text('Price',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade400)),
                          Text('฿${item.deal.price.toStringAsFixed(0)} each',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.bold)),
                        ] else ...[
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '฿${(item.deal.price * item.quantity).toStringAsFixed(0)} ',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: AppConfig.primaryGreen,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: item.quantity == 1 ? 'each' : 'total',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.remove,
                                      size: 16, color: Colors.grey.shade600),
                                  onPressed: () => cart.decrement(item.deal.id),
                                ),
                                Text('${item.quantity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.add,
                                      size: 16, color: Colors.grey.shade600),
                                  onPressed: () => cart.add(item.deal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isExpired) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(Icons.error,
                                color: Colors.red.shade400, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('This surplus item was released',
                                  style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontSize: 11)),
                            ),
                            InkWell(
                              onTap: () => cart.remove(item.deal.id),
                              child: Text('Remove',
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        if (cart.items.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();

        final validItems = cart.items.where((i) {
          final isResExpired =
              i.expiresAt != null && i.expiresAt!.isBefore(now);
          final isFlashExpired = i.deal.flashSaleEndsAt != null &&
              i.deal.flashSaleEndsAt!.isBefore(now);
          return !isResExpired && !isFlashExpired;
        }).toList();

        final validTotal = validItems.fold(0.0, (sum, i) => sum + i.lineTotal);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 13)),
                  Text('฿${validTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: FilledButton(
                  onPressed:
                      (controller.isCheckingOut.value || validItems.isEmpty)
                          ? null
                          : controller.checkout,
                  child: controller.isCheckingOut.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Checkout'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
