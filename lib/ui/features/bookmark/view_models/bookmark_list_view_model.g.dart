// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_list_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BookmarkListViewModel)
final bookmarkListViewModelProvider = BookmarkListViewModelProvider._();

final class BookmarkListViewModelProvider
    extends
        $AsyncNotifierProvider<BookmarkListViewModel, List<PerformanceDetail>> {
  BookmarkListViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkListViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkListViewModelHash();

  @$internal
  @override
  BookmarkListViewModel create() => BookmarkListViewModel();
}

String _$bookmarkListViewModelHash() =>
    r'43688d5569edd3bb79008a29d258611014a1f3c5';

abstract class _$BookmarkListViewModel
    extends $AsyncNotifier<List<PerformanceDetail>> {
  FutureOr<List<PerformanceDetail>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PerformanceDetail>>,
              List<PerformanceDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PerformanceDetail>>,
                List<PerformanceDetail>
              >,
              AsyncValue<List<PerformanceDetail>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
