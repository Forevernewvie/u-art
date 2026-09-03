import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rxdart/rxdart.dart';
import '../view_models/search_view_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchSubject = PublishSubject<String>();
  String _selectedGenre = '전체';

  final List<String> _genres = [
    '전체',
    '뮤지컬',
    '연극',
    '서양음악(클래식)',
    '한국음악(국악)',
    '대중음악',
    '무용',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _searchSubject.debounceTime(const Duration(milliseconds: 300)).listen((
      query,
    ) {
      ref.read(searchViewModelProvider.notifier).search(query, _selectedGenre);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('공연 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '공연 제목 또는 공연장 검색 (예: 중구, 문예회관)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => _searchSubject.add(val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _genres.map((genre) {
                final isSelected = _selectedGenre == genre;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      genre == '서양음악(클래식)'
                          ? '클래식'
                          : (genre == '한국음악(국악)' ? '국악' : genre),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedGenre = genre);
                        ref
                            .read(searchViewModelProvider.notifier)
                            .search(_searchController.text, genre);
                      }
                    },
                    selectedColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: state.when(
              data: (performances) {
                if (performances.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text(
                          '해당 조건에 맞는 공연이 없습니다.',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '다른 장르나 검색어로 찾아보시겠어요?',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(searchViewModelProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: performances.length,
                    itemBuilder: (context, index) {
                      final perf = performances[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: perf.posterUrl,
                            width: 60,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                        title: Text(
                          perf.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${perf.genre} • ${perf.venue}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${perf.startDate} ~ ${perf.endDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () => context.pushNamed(
                          'search_detail',
                          pathParameters: {'id': perf.id},
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      '네트워크 오류가 발생했습니다.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(searchViewModelProvider.notifier).refresh(),
                      child: const Text('재시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
