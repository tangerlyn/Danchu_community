import 'package:get/get.dart';

import '../../../data/providers/naver_api_provider.dart';
import '../../../data/repositories/search_repository_impl.dart';
import '../../../data/repositories/review_repository_impl.dart';
import '../controllers/home_controller.dart';

/// Binding for HomeView — creates HomeController with dependencies.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Data layer
    Get.lazyPut<NaverApiProvider>(() => NaverApiProvider());
    Get.lazyPut<SearchRepositoryImpl>(
      () => SearchRepositoryImpl(apiProvider: Get.find<NaverApiProvider>()),
    );

    // Presentation layer
    Get.lazyPut<HomeController>(
      () => HomeController(repository: Get.find<SearchRepositoryImpl>()),
    );
    
    // Reviews
    Get.lazyPut<ReviewRepositoryImpl>(() => ReviewRepositoryImpl());
  }
}
