import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:u_art/data/models/performance.dart';
import '../view_models/detail_view_model.dart';
import '../../bookmark/view_models/bookmark_view_model.dart';

class DetailScreen extends ConsumerWidget {
  final String id;
  const DetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(detailViewModelProvider(id));
    final bookmarks = ref.watch(bookmarkProvider);
    final isBookmarked = bookmarks.contains(id);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.favorite : Icons.favorite_border,
              color: isBookmarked ? Colors.red : Colors.white,
            ),
            onPressed: () {
              ref.read(bookmarkProvider.notifier).toggleBookmark(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isBookmarked ? '찜 목록에서 삭제되었습니다.' : '찜 목록에 추가되었습니다.',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: state.when(
        data: (detail) {
          final bool hasBooking = detail.bookingLinks.isNotEmpty;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'poster_$id',
                      child: CachedNetworkImage(
                        imageUrl: detail.posterUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  detail.genre,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  detail.state,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            detail.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow(
                            Icons.calendar_today,
                            '공연기간',
                            '${detail.startDate} ~ ${detail.endDate}',
                          ),
                          _buildInfoRow(
                            Icons.schedule,
                            '공연시간',
                            detail.timeGuidance,
                          ),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            '관람시간',
                            detail.runtime,
                          ),
                          _buildInfoRow(
                            Icons.location_on,
                            '공연장소',
                            detail.venue,
                          ),
                          _buildInfoRow(Icons.person, '관람연령', detail.ageLimit),
                          _buildInfoRow(
                            Icons.confirmation_number_outlined,
                            '티켓가격',
                            detail.price,
                          ),
                          _buildInfoRow(Icons.groups, '출연진', detail.cast),

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _addToCalendar(
                                  context,
                                  detail.title,
                                  detail.venue,
                                  detail.startDate,
                                  detail.endDate,
                                );
                              },
                              icon: const Icon(
                                Icons.calendar_month,
                                color: Colors.white,
                              ),
                              label: const Text(
                                '내 캘린더에 일정 추가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          if (detail.detailImages.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            const Text(
                              '공연 상세 안내',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...detail.detailImages.map(
                              (url) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasBooking)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleBooking(context, detail.bookingLinks),
                      icon: const Icon(Icons.confirmation_number, size: 22),
                      label: Text(
                        detail.bookingLinks.length > 1
                            ? '예매처 바로가기 (${detail.bookingLinks.length}곳)'
                            : '지금 예매하기 (${detail.bookingLinks.first.name})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류 발생\n$error')),
      ),
    );
  }

  void _handleBooking(BuildContext context, List<BookingLink> links) {
    if (links.length == 1) {
      _launchUrl(links.first.url);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '예매처를 선택해주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...links.map(
                    (link) => ListTile(
                      leading: const Icon(
                        Icons.open_in_new,
                        color: Colors.amber,
                      ),
                      title: Text(
                        link.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        link.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchUrl(link.url);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty || value.trim() == '정보 없음') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCalendar(
    BuildContext context,
    String title,
    String venue,
    String start,
    String end,
  ) {
    try {
      final startDate = DateTime.parse(start.replaceAll('.', ''));
      final endDate = DateTime.parse(end.replaceAll('.', ''));

      final event = Event(
        title: title,
        description: 'U-Art에서 추가된 공연입니다.',
        location: venue,
        startDate: startDate,
        endDate: endDate.add(const Duration(days: 1)),
        allDay: true,
      );

      Add2Calendar.addEvent2Cal(event).then((success) {
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 형식이 올바르지 않아 추가할 수 없습니다.')),
      );
    }
  }
}
