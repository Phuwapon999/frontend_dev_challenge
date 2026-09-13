import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/home/widget/flash_deals_section_controller.dart';
import 'package:rescu/feature/shared_widget/deal_card.dart';
import 'package:rescu/feature/shared_widget/deal_impression_tracker.dart';

import '../../../app_config.dart';
import '../../../model/deal_model.dart';
import '../../../routes/routes.dart';
import '../../shared_widget/the_network_image.dart';

/// Horizontal flash-sale rail.
///
/// NOTE: the countdown is currently a static "Ends soon" label — turning it
/// into a live per-deal countdown is one of the feature tasks in PROBLEM.md.
class FlashDealsSection extends StatelessWidget {
  final List<DealModel> deals;

  const FlashDealsSection({super.key, required this.deals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.red, size: 20),
              SizedBox(width: 4),
              Text('Flash sales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: deals.length,
            itemBuilder: (context, index) {
              final deal = deals[index];
              return StreamBuilder<bool>(
                initialData: deal.flashSaleEndsAt != null &&
                    deal.flashSaleEndsAt!.difference(DateTime.now()).isNegative,
                stream: deal.flashSaleEndsAt == null
                    ? Stream.value(false)
                    : Stream.periodic(
                        const Duration(seconds: 1),
                        (_) => deal.flashSaleEndsAt!
                            .difference(DateTime.now())
                            .isNegative,
                      ).distinct(),
                builder: (context, snapshot) {
                  final isExpired = snapshot.data ?? false;

                  return DealImpressionTracker(
                    dealId: deal.id,
                    source: 'flash_rail',
                    position: index,
                    child: SizedBox(
                      width: 200,
                      child: Opacity(
                        opacity: isExpired ? 0.6 : 1.0,
                        child: Card(
                          color:
                              isExpired ? Colors.grey.shade200 : Colors.white,
                          elevation: 0.5,
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: isExpired
                                ? null
                                : () {
                                    Get.toNamed(
                                      Routes.dealRoute(deal.id,
                                          source: 'flash_rail'),
                                      arguments: deal,
                                    );
                                  },
                            child: ColorFiltered(
                              colorFilter: isExpired
                                  ? const ColorFilter.matrix([
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ])
                                  : const ColorFilter.mode(
                                      Colors.transparent, BlendMode.multiply),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TheNetworkImage(
                                      url: deal.imageUrl,
                                      height: 90,
                                      width: double.infinity),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(deal.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        Text(deal.storeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey.shade600)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                                '฿${deal.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isExpired
                                                        ? Colors.grey.shade700
                                                        : AppConfig
                                                            .primaryGreen)),
                                            const Spacer(),
                                            if (deal.flashSaleEndsAt != null)
                                              FlashDealsSectionController(
                                                  endsAt:
                                                      deal.flashSaleEndsAt!),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
