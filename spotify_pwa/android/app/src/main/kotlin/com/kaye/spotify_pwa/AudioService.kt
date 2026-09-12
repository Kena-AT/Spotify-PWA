package com.kaye.spotify_pwa

import android.app.Service
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.net.URL
import java.util.concurrent.Executors

class AudioService : Service() {
  companion object {
    const val CHANNEL_ID = "spotify_audio"
    const val NOTIFICATION_ID = 1
    const val ACTION_PLAY = "com.kaye.spotify_pwa.PLAY"
    const val ACTION_PAUSE = "com.kaye.spotify_pwa.PAUSE"
    const val ACTION_NEXT = "com.kaye.spotify_pwa.NEXT"
    const val ACTION_PREVIOUS = "com.kaye.spotify_pwa.PREVIOUS"
    const val ACTION_STOP = "com.kaye.spotify_pwa.STOP"
    const val ACTION_UPDATE = "com.kaye.spotify_pwa.UPDATE"
  }

  private lateinit var mediaSession: MediaSessionCompat
  private var isPlaying = false
  private var currentTitle = "Spotify"
  private var currentArtist = ""
  private var currentAlbumArtUrl: String? = null
  private var currentAlbumArtBitmap: Bitmap? = null
  private var currentPosition: Long = 0L
  private var currentDuration: Long = 0L

  private val executorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onCreate() {
    super.onCreate()
    createNotificationChannel()
    initializeMediaSession()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Spotify Audio",
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Spotify Music Playback"
        setShowBadge(false)
      }
      val manager = getSystemService(NotificationManager::class.java)
      manager?.createNotificationChannel(channel)
    }
  }

  private fun initializeMediaSession() {
    mediaSession = MediaSessionCompat(this, "SpotifyAudio").apply {
      setCallback(MediaSessionCallback())
      isActive = true
      setPlaybackState(
        PlaybackStateCompat.Builder()
          .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 0f)
          .setActions(
            PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_PLAY_PAUSE or
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
            PlaybackStateCompat.ACTION_STOP
          )
          .build()
      )
    }
    startForeground(NOTIFICATION_ID, buildNotification())
  }

  private fun buildNotification(): android.app.Notification {
    val openIntent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val contentPendingIntent = PendingIntent.getActivity(
      this, 0, openIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val playPauseAction = if (isPlaying) {
      NotificationCompat.Action(
        android.R.drawable.ic_media_pause,
        "Pause",
        getPendingIntentForAction(ACTION_PAUSE)
      )
    } else {
      NotificationCompat.Action(
        android.R.drawable.ic_media_play,
        "Play",
        getPendingIntentForAction(ACTION_PLAY)
      )
    }

    val stopAction = NotificationCompat.Action(
      android.R.drawable.ic_menu_close_clear_cancel,
      "Close",
      getPendingIntentForAction(ACTION_STOP)
    )

    val deletePendingIntent = getPendingIntentForAction(ACTION_STOP)

    val builder = NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle(currentTitle)
      .setContentText(if (currentArtist.isNotEmpty()) currentArtist else "Spotify")
      .setSmallIcon(R.drawable.ic_notification)
      .setContentIntent(contentPendingIntent)
      .setDeleteIntent(deletePendingIntent)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .addAction(
        android.R.drawable.ic_media_previous,
        "Previous",
        getPendingIntentForAction(ACTION_PREVIOUS)
      )
      .addAction(playPauseAction)
      .addAction(
        android.R.drawable.ic_media_next,
        "Next",
        getPendingIntentForAction(ACTION_NEXT)
      )
      .addAction(stopAction)
      .setStyle(
        androidx.media.app.NotificationCompat.MediaStyle()
          .setMediaSession(mediaSession.sessionToken)
          .setShowActionsInCompactView(0, 1, 2)
      )
      .setOngoing(isPlaying)

    if (currentAlbumArtBitmap != null) {
      builder.setLargeIcon(currentAlbumArtBitmap)
    }

    return builder.build()
  }

  private fun getPendingIntentForAction(action: String): PendingIntent {
    val intent = Intent(this, AudioService::class.java).apply {
      this.action = action
    }
    return PendingIntent.getService(
      this, action.hashCode(), intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent == null) return START_NOT_STICKY

    when (intent.action) {
      ACTION_PLAY -> onPlayRequested()
      ACTION_PAUSE -> onPauseRequested()
      ACTION_NEXT -> sendCommandToFlutter("next")
      ACTION_PREVIOUS -> sendCommandToFlutter("previous")
      ACTION_STOP -> stopAudioService()
      else -> {
        val title = intent.getStringExtra("title")
        if (title != null && title.isNotEmpty()) {
          val artist = intent.getStringExtra("artist") ?: ""
          val playing = intent.getBooleanExtra("isPlaying", false)
          val albumArtUrl = intent.getStringExtra("albumArtUrl")
          val position = intent.getLongExtra("position", 0L)
          val duration = intent.getLongExtra("duration", 0L)
          updatePlaybackStateInternal(title, artist, playing, albumArtUrl, position, duration)
        }
      }
    }
    return START_NOT_STICKY
  }

  private fun onPlayRequested() {
    isPlaying = true
    val playbackState = PlaybackStateCompat.Builder()
      .setState(PlaybackStateCompat.STATE_PLAYING, currentPosition, 1.0f)
      .setActions(
        PlaybackStateCompat.ACTION_PLAY or
        PlaybackStateCompat.ACTION_PAUSE or
        PlaybackStateCompat.ACTION_PLAY_PAUSE or
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
        PlaybackStateCompat.ACTION_STOP
      )
      .build()
    mediaSession.setPlaybackState(playbackState)
    startForeground(NOTIFICATION_ID, buildNotification())
    sendCommandToFlutter("play")
  }

  private fun onPauseRequested() {
    isPlaying = false
    val playbackState = PlaybackStateCompat.Builder()
      .setState(PlaybackStateCompat.STATE_PAUSED, currentPosition, 0f)
      .setActions(
        PlaybackStateCompat.ACTION_PLAY or
        PlaybackStateCompat.ACTION_PAUSE or
        PlaybackStateCompat.ACTION_PLAY_PAUSE or
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
        PlaybackStateCompat.ACTION_STOP
      )
      .build()
    mediaSession.setPlaybackState(playbackState)

    // Detach from foreground so the notification is immediately dismissible
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_DETACH)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(false)
    }
    val manager = getSystemService(NotificationManager::class.java)
    manager?.notify(NOTIFICATION_ID, buildNotification())

    sendCommandToFlutter("pause")
  }

  private fun sendCommandToFlutter(command: String) {
    mainHandler.post {
      MainActivity.audioMethodChannel?.invokeMethod(
        "handlePlaybackControl",
        mapOf("action" to command)
      )
    }
  }

  private fun updatePlaybackStateInternal(
    title: String,
    artist: String,
    playing: Boolean,
    albumArtUrl: String?,
    position: Long,
    duration: Long
  ) {
    currentTitle = title
    currentArtist = artist
    isPlaying = playing
    currentPosition = position
    currentDuration = duration

    val state = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
    val playbackState = PlaybackStateCompat.Builder()
      .setState(state, position, if (playing) 1.0f else 0.0f)
      .setActions(
        PlaybackStateCompat.ACTION_PLAY or
        PlaybackStateCompat.ACTION_PAUSE or
        PlaybackStateCompat.ACTION_PLAY_PAUSE or
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
        PlaybackStateCompat.ACTION_STOP
      )
      .build()
    mediaSession.setPlaybackState(playbackState)

    val metadataBuilder = MediaMetadataCompat.Builder()
      .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
      .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
      .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Spotify")

    if (duration > 0) {
      metadataBuilder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
    }

    if (currentAlbumArtBitmap != null) {
      metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentAlbumArtBitmap)
      metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, currentAlbumArtBitmap)
    }
    mediaSession.setMetadata(metadataBuilder.build())

    if (albumArtUrl != null && albumArtUrl != currentAlbumArtUrl) {
      currentAlbumArtUrl = albumArtUrl
      fetchAlbumArtAndNotify(albumArtUrl, metadataBuilder)
    } else {
      notifyUpdated()
    }
  }

  private fun fetchAlbumArtAndNotify(url: String, metadataBuilder: MediaMetadataCompat.Builder) {
    executorService.execute {
      try {
        val connection = URL(url).openConnection()
        connection.connectTimeout = 5000
        connection.readTimeout = 5000
        val input = connection.getInputStream()
        val bitmap = BitmapFactory.decodeStream(input)
        
        currentAlbumArtBitmap = bitmap
        
        metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
        metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, bitmap)
        mediaSession.setMetadata(metadataBuilder.build())
        
        notifyUpdated()
      } catch (e: Exception) {
        e.printStackTrace()
        notifyUpdated()
      }
    }
  }

  private fun notifyUpdated() {
    val manager = getSystemService(NotificationManager::class.java)
    val notification = buildNotification()

    if (isPlaying) {
      startForeground(NOTIFICATION_ID, notification)
    } else {
      // Paused: detach foreground so notification can be swiped away
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_DETACH)
      } else {
        @Suppress("DEPRECATION")
        stopForeground(false)
      }
      manager?.notify(NOTIFICATION_ID, notification)
    }
  }

  fun stopAudioService() {
    isPlaying = false
    mediaSession.isActive = false
    val playbackState = PlaybackStateCompat.Builder()
      .setState(PlaybackStateCompat.STATE_STOPPED, 0L, 0f)
      .build()
    mediaSession.setPlaybackState(playbackState)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }
    val manager = getSystemService(NotificationManager::class.java)
    manager?.cancel(NOTIFICATION_ID)
    stopSelf()
  }

  override fun onTaskRemoved(rootIntent: Intent?) {
    super.onTaskRemoved(rootIntent)
    // App was removed from recents: stop service immediately
    stopAudioService()
  }

  private inner class MediaSessionCallback : MediaSessionCompat.Callback() {
    override fun onPlay() = onPlayRequested()
    override fun onPause() = onPauseRequested()
    override fun onSkipToNext() = sendCommandToFlutter("next")
    override fun onSkipToPrevious() = sendCommandToFlutter("previous")
    override fun onStop() = stopAudioService()
  }

  override fun onDestroy() {
    executorService.shutdown()
    mediaSession.isActive = false
    mediaSession.release()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }
    val manager = getSystemService(NotificationManager::class.java)
    manager?.cancel(NOTIFICATION_ID)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null
}
