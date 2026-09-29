package com.sentinela.sentinela_app

import android.content.Context
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val AUDIO_CHANNEL = "facetrack/audio"
    }

    private var alertPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "playLoop" -> {
                            val tone = call.argument<String>("tone") ?: "electronic_one"
                            val volume =
                                (call.argument<Number>("volume")?.toFloat() ?: 0.8f)
                                    .coerceIn(0f, 1f)
                            playAlertLoop(tone, volume)
                            result.success(null)
                        }

                        "setVolume" -> {
                            val volume =
                                (call.argument<Number>("volume")?.toFloat() ?: 0.8f)
                                    .coerceIn(0f, 1f)
                            alertPlayer?.setVolume(volume, volume)
                            result.success(null)
                        }

                        "stop" -> {
                            stopAlertAudio()
                            result.success(null)
                        }

                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    stopAlertAudio()
                    result.error(
                        "FACETRACK_AUDIO_ERROR",
                        error.message ?: "Falha ao reproduzir o áudio interno.",
                        error.javaClass.simpleName,
                    )
                }
            }
    }

    override fun onDestroy() {
        stopAlertAudio()
        cancelActiveVibration()
        cancelFaceTrackNotifications()
        super.onDestroy()
    }

    private fun playAlertLoop(tone: String, volume: Float) {
        stopAlertAudio()
        val resourceId = when (tone) {
            "electronic_two" -> R.raw.facetrack_error2
            "electronic_three" -> R.raw.facetrack_error3
            else -> R.raw.facetrack_error1
        }

        val descriptor = resources.openRawResourceFd(resourceId)
        try {
            alertPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
                isLooping = true
                setVolume(volume, volume)
                prepare()
                start()
            }
        } finally {
            descriptor.close()
        }
    }

    private fun stopAlertAudio() {
        alertPlayer?.runCatching {
            if (isPlaying) stop()
            reset()
            release()
        }
        alertPlayer = null
    }

    private fun cancelActiveVibration() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.cancel()
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.cancel()
        }
    }

    private fun cancelFaceTrackNotifications() {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Todas as notificações pertencem exclusivamente ao FaceTrack. Ao
        // remover o app dos recentes, nenhuma delas deve permanecer visível.
        notificationManager.cancelAll()
    }
}
