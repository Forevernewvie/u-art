// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'performance_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(uartApiService)
final uartApiServiceProvider = UartApiServiceProvider._();

final class UartApiServiceProvider
    extends $FunctionalProvider<UartApiService, UartApiService, UartApiService>
    with $Provider<UartApiService> {
  UartApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uartApiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uartApiServiceHash();

  @$internal
  @override
  $ProviderElement<UartApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UartApiService create(Ref ref) {
    return uartApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UartApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UartApiService>(value),
    );
  }
}

String _$uartApiServiceHash() => r'71877ab891e1166a88ba41d97d7cf53ae26e88bc';

@ProviderFor(performanceRepository)
final performanceRepositoryProvider = PerformanceRepositoryProvider._();

final class PerformanceRepositoryProvider
    extends
        $FunctionalProvider<
          PerformanceRepository,
          PerformanceRepository,
          PerformanceRepository
        >
    with $Provider<PerformanceRepository> {
  PerformanceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'performanceRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$performanceRepositoryHash();

  @$internal
  @override
  $ProviderElement<PerformanceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PerformanceRepository create(Ref ref) {
    return performanceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PerformanceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PerformanceRepository>(value),
    );
  }
}

String _$performanceRepositoryHash() =>
    r'cbe89dbb6d9a6cf55c8c18579dd0c208678d0593';
