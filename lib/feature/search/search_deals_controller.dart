import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  String _latestSearchQuery = '';

  void onQueryChanged(String query) {
    _search(query);
  }

  Future<void> _search(String query) async {
    final currentQuery = query.trim();
    _latestSearchQuery = currentQuery;
    if (currentQuery.isEmpty) {
      results.clear();
      hasSearched.value = false;
      return;
    }
    isLoading.value = true;
    hasSearched.value = true;
    try {
      final found = await dealRepo.search(currentQuery);
      if (_latestSearchQuery == currentQuery) {
        results.assignAll(found);
      }
    } catch (e) {
      LogService.error('search failed', e);
    } finally {
      if (_latestSearchQuery == currentQuery) {
        isLoading.value = false;
      }
    }
  }
}
