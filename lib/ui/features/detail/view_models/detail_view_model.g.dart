// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DetailViewModel)
final detailViewModelProvider = DetailViewModelFamily._();

final class DetailViewModelProvider
    extends $AsyncNotifierProvider<DetailViewModel, PerformanceDetail> {
  DetailViewModelProvider._({
    required DetailViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'detailViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$detailViewModelHash();

  @override
  String toString() {
    return r'detailViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DetailViewModel create() => DetailViewModel();

  @override
  bool operator ==(Object other) {
    return other is DetailViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$detailViewModelHash() => r'b99f33c3a77aa30e8e80a97690fd82ec518a3dfc';

final class DetailViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          DetailViewModel,
          AsyncValue<PerformanceDetail>,
          PerformanceDetail,
          FutureOr<PerformanceDetail>,
          String
        > {
  DetailViewModelFamily._()
    : super(
        retry: null,
        name: r'detailViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DetailViewModelProvider call(String id) =>
      DetailViewModelProvider._(argument: id, from: this);

  @override
  String toString() => r'detailViewModelProvider';
}

abstract class _$DetailViewModel extends $AsyncNotifier<PerformanceDetail> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<PerformanceDetail> build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PerformanceDetail>, PerformanceDetail>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PerformanceDetail>, PerformanceDetail>,
              AsyncValue<PerformanceDetail>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
