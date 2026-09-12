part of 'detections_cubit.dart';

enum DetectionsStatus { initial, loading, success, failure }

final class DetectionsState extends Equatable {
  const DetectionsState({
    this.status = DetectionsStatus.initial,
    this.detections = const <Detection>[],
    this.filter,
    this.errorMessage,
  });

  final DetectionsStatus status;
  final List<Detection> detections;

  /// `null` significa "todos".
  final DetectionStatus? filter;
  final String? errorMessage;

  bool get isLoading => status == DetectionsStatus.loading;

  List<Detection> get filteredDetections => filter == null
      ? detections
      : detections.where((d) => d.status == filter).toList();

  DetectionsState copyWith({
    DetectionsStatus? status,
    List<Detection>? detections,
    DetectionStatus? filter,
    bool clearFilter = false,
    String? errorMessage,
  }) {
    return DetectionsState(
      status: status ?? this.status,
      detections: detections ?? this.detections,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, detections, filter, errorMessage];
}
