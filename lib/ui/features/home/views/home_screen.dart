import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../view_models/home_view_model.dart';
import 'widgets/kopis_disclaimer.dart';
import 'package:u_art/ui/common_widgets/sold_out_stamp.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('U-Art'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: state.when(
        data: (performances) {
          if (performances.isEmpty) {
            return const Center(child: Text('예정된 공연이 없습니다.'));
          }

          final carouselItems = performances
              .take(5)
              .toList(); // Top 5 for carousel
          final listItems = performances; // All 14 days

          return RefreshIndicator(
            onRefresh: () => ref.read(homeViewModelProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 450,
                        enlargeCenterPage: true,
                        viewportFraction: 0.8,
                        autoPlay: true,
                        enableInfiniteScroll: false,
                      ),
                      items: carouselItems.map((perf) {
                        return GestureDetector(
                          onTap: () => context.pushNamed(
                            'home_detail',
                            pathParameters: {'id': perf.id},
                          ),
                          child: Hero(
                            tag: 'poster_${perf.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: perf.posterUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                  if (perf.isSoldOut)
                                    const SoldOutStamp(size: StampSize.regular),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: ClipRect(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                perf.genre,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                perf.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${perf.startDate} ~ ${perf.endDate} | ${perf.venue}',
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      '최근 14일간 공연',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final perf = listItems[index];
                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: perf.posterUrl,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                          if (perf.isSoldOut)
                            const Positioned(
                              top: -4,
                              right: -4,
                              child: SoldOutStamp(
                                size: StampSize.compact,
                                showOverlay: false,
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        perf.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: perf.isSoldOut
                              ? TextDecoration.lineThrough
                              : null,
                          color: perf.isSoldOut ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        '${perf.venue}\n${perf.startDate} ~ ${perf.endDate}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushNamed(
                        'home_detail',
                        pathParameters: {'id': perf.id},
                      ),
                    );
                  }, childCount: listItems.length),
                ),
                const SliverToBoxAdapter(child: KopisDisclaimer()),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('오류가 발생했습니다.\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
