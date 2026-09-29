import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../data/models/alert_tone.dart';

final class AlertPreferencesState extends Equatable {
  const AlertPreferencesState({
    this.tone = AlertTone.electronicOne,
    this.volume = 0.8,
    this.isLoaded = false,
  });

  final AlertTone tone;
  final double volume;
  final bool isLoaded;

  @override
  List<Object?> get props => [tone, volume, isLoaded];
}

class AlertPreferencesCubit extends Cubit<AlertPreferencesState> {
  AlertPreferencesCubit({SecureStorageService? storage})
    : _storage = storage ?? SecureStorageService(),
      super(const AlertPreferencesState());

  final SecureStorageService _storage;

  Future<void> load() async {
    try {
      final savedTone = await _storage.readAlertTone();
      final savedVolume = double.tryParse(
        await _storage.readAlertVolume() ?? '',
      );
      if (!isClosed) {
        emit(
          AlertPreferencesState(
            tone: AlertTone.fromStorage(savedTone),
            volume: (savedVolume ?? 0.8).clamp(0.0, 1.0).toDouble(),
            isLoaded: true,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(const AlertPreferencesState(isLoaded: true));
      }
    }
  }

  Future<void> selectTone(AlertTone tone) async {
    if (tone == state.tone && state.isLoaded) return;
    final previous = state;
    emit(
      AlertPreferencesState(tone: tone, volume: state.volume, isLoaded: true),
    );
    try {
      await _storage.saveAlertTone(tone.storageValue);
    } catch (_) {
      if (!isClosed) emit(previous);
    }
  }

  Future<void> selectVolume(double volume, {bool persist = true}) async {
    final normalized = volume.clamp(0.0, 1.0).toDouble();
    final previous = state;
    emit(
      AlertPreferencesState(
        tone: state.tone,
        volume: normalized,
        isLoaded: true,
      ),
    );
    if (!persist) return;
    try {
      await _storage.saveAlertVolume(normalized);
    } catch (_) {
      if (!isClosed) emit(previous);
    }
  }
}
