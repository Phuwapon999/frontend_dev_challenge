import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../app_config.dart';
import '../../routes/routes.dart';
import '../shared_widget/deal_card.dart';
import '../shared_widget/shimmer_deal_card.dart';
import 'home_controller.dart';
import 'widget/flash_deals_section.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() {
          final offset = controller.scrollOffset.value;
          return AppBar(
            elevation: offset > 4 ? 2 : 0,
            shadowColor: Colors.black26,
            title: const Row(
              children: [
                Icon(Icons.eco, color: AppConfig.primaryGreen),
                SizedBox(width: 8),
                Text('Rescu',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Get.toNamed(Routes.search),
              ),
              IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: () => Get.toNamed(Routes.map),
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () => Get.toNamed(Routes.orders),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () => Get.toNamed(Routes.cart),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deeplink') _showDeepLinkDialog(context);
                  if (value == 'analytics') Get.toNamed(Routes.analyticsDebug);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'deeplink', child: Text('Simulate deep link…')),
                  PopupMenuItem(
                      value: 'analytics', child: Text('Analytics debug')),
                ],
              ),
            ],
          );
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) => const ShimmerDealCard(),
          );
        }

        return SmartRefresher(
          controller: controller.refreshController,
          enablePullDown: true,
          enablePullUp: true,
          onRefresh: controller.refreshDeals,
          onLoading: controller.loadMore,
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              Obx(() => controller.flashDeals.isNotEmpty
                  ? SliverToBoxAdapter(
                      child: FlashDealsSection(deals: controller.flashDeals),
                    )
                  : const SliverToBoxAdapter(child: SizedBox.shrink())),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text('Nearby deals',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Obx(() => FilterChip(
                            label: const Text('Pickup today'),
                            selected: controller.todayOnly.value,
                            onSelected: (v) => controller.todayOnly.value = v,
                          )),
                    ],
                  ),
                ),
              ),
              Obx(() => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          DealCard(deal: controller.visibleDeals[index]),
                      childCount: controller.visibleDeals.length,
                    ),
                  )),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        );
      }),
      floatingActionButton: Obx(() => controller.scrollOffset.value > 800
          ? FloatingActionButton.small(
              onPressed: controller.scrollToTop,
              child: const Icon(Icons.arrow_upward),
            )
          : const SizedBox.shrink()),
    );
  }

  void _showDeepLinkDialog(BuildContext context) {
    final textController =
        TextEditingController(text: 'rescu://open/deal?id=42&source=push');
    Get.dialog(
      AlertDialog(
        title: const Text('Simulate deep link'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            helperText: 'e.g. rescu://open/deal?id=42&source=push',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final uri = Uri.tryParse(textController.text.trim());
              Get.back();
              if (uri == null) return;
              final route =
                  uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
              Get.toNamed(route);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
