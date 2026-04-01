import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/community_post.dart';
import 'community_controller.dart';
import 'widgets/post_card_widget.dart';

/// Dedicated search page for community posts.
class CommunitySearchPage extends StatefulWidget {
  final String currentTab;
  const CommunitySearchPage({super.key, required this.currentTab});

  @override
  State<CommunitySearchPage> createState() => _CommunitySearchPageState();
}

class _CommunitySearchPageState extends State<CommunitySearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final CommunityController _communityCtrl = Get.find<CommunityController>();

  List<CommunityPost> _searchResults = [];
  String _activeQuery = '';
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _focusNode.unfocus();
    _communityCtrl.addSearchHistory(trimmed);

    setState(() {
      _activeQuery = trimmed;
      _hasSearched = true;
      _searchResults = _communityCtrl.searchPosts(trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deepBrown),
          onPressed: () => Get.back(),
        ),
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onSubmitted: _performSearch,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: {
                '산책': '산책 게시글 검색...',
                '신고': '신고 게시글 검색...',
                '모임': '모임 게시글 검색...',
                '자유': '자유 게시글 검색...',
              }[widget.currentTab] ?? '게시글 검색...',
              hintStyle: TextStyle(color: AppColors.taupe.withOpacity(0.6), fontSize: 15),
              prefixIcon: const Icon(Icons.search, color: AppColors.taupe, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.taupe),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _hasSearched = false;
                          _activeQuery = '';
                          _searchResults = [];
                        });
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppColors.deepBrown.withOpacity(0.3), width: 1),
              ),
            ),
            style: const TextStyle(fontSize: 15, color: AppColors.deepBrown),
          ),
        ),
      ),
      body: _hasSearched ? _buildSearchResults() : _buildRecentSearches(),
    );
  }


  // ─── Recent Searches ─────────────────────────────────────

  Widget _buildRecentSearches() {
    return Obx(() {
      final history = _communityCtrl.searchHistory;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 검색어',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                if (history.isNotEmpty)
                  GestureDetector(
                    onTap: () => _communityCtrl.clearAllSearchHistory(),
                    child: const Text(
                      '전체 삭제',
                      style: TextStyle(fontSize: 13, color: AppColors.taupe),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // List
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    '최근 검색 기록이 없습니다.',
                    style: TextStyle(fontSize: 14, color: AppColors.taupe),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.sand),
                  itemBuilder: (context, index) {
                    final query = history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history, color: AppColors.taupe.withOpacity(0.6), size: 20),
                      title: Text(
                        query,
                        style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 16, color: AppColors.taupe.withOpacity(0.6)),
                        onPressed: () => _communityCtrl.removeSearchHistory(query),
                      ),
                      onTap: () {
                        _searchController.text = query;
                        _performSearch(query);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }

  // ─── Search Results ──────────────────────────────────────

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.taupe.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              '"$_activeQuery" 검색 결과가 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.taupe, fontSize: 16, height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 32, color: AppColors.sand),
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return PostCardWidget(
          post: post,
          highlightQuery: _activeQuery,
        );
      },
    );
  }

}
