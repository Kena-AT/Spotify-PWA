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
import android.os.IBinder
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
    const val ACTION_UPDATE = "com.kaye.spotify_pwa.UPDATE"
  }

  private lateinit var mediaSession: MediaSessionCompat
  private var isPlaying = false
  private var currentTitle = "Spotify"
  private var currentArtist = ""
  private var currentAlbumArtUrl: String? = null
  private var currentAlbumArtBitmap: Bitmap? = null

  private val executorService = Executors.newSingleThreadExecutor()

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
          .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1f)
          .setActions(
            PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
          )
          .build()
      )
    }
    startForeground(NOTIFICATION_ID, buildNotification())
  }

  private fun buildNotification(): android.app.Notification {
    val intent = Intent(this, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
      this, 0, intent,
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

    val builder = NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle(currentTitle)
      .setContentText(currentArtist)
      .setSmallIcon(android.R.drawable.ic_media_play) // TODO: use app icon if available
      .setContentIntent(pendingIntent)
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
    if (intent == null) return START_STICKY

    when (intent.action) {
      ACTION_PLAY -> sendCommandToFlutter("play")
      ACTION_PAUSE -> sendCommandToFlutter("pause")
      ACTION_NEXT -> sendCommandToFlutter("next")
      ACTION_PREVIOUS -> sendCommandToFlutter("previous")
      else -> {
        // Handle update
        val title = intent.getStringExtra("title")
        if (title != null) {
          val artist = intent.getStringExtra("artist") ?: ""
          val playing = intent.getBooleanExtra("isPlaying", false)
          val albumArtUrl = intent.getStringExtra("albumArtUrl")
          updatePlaybackStateInternal(title, artist, playing, albumArtUrl)
        }
      }
    }
    return START_STICKY
  }

  private fun sendCommandToFlutter(command: String) {
    MainActivity.audioMethodChannel?.invokeMethod(
      "handlePlaybackControl",
      mapOf("action" to command)
    )
  }

  private fun updatePlaybackStateInternal(title: String, artist: String, playing: Boolean, albumArtUrl: String?) {
    currentTitle = title
    currentArtist = artist
    isPlaying = playing

    // Update MediaSession
    val playbackState = PlaybackStateCompat.Builder()
      .setState(
        if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
        0L,
        1f
      )
      .setActions(
        PlaybackStateCompat.ACTION_PLAY or
        PlaybackStateCompat.ACTION_PAUSE or
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
      )
      .build()
    mediaSession.setPlaybackState(playbackState)

    // Update metadata (for lock screen)
    val metadataBuilder = MediaMetadataCompat.Builder()
      .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
      .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)

    if (currentAlbumArtBitmap != null) {
      metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentAlbumArtBitmap)
    }
    mediaSession.setMetadata(metadataBuilder.build())

    // If album art changed, fetch it. Otherwise just update notification.
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
        
        // Update metadata with bitmap
        metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
        mediaSession.setMetadata(metadataBuilder.build())
        
        // Notify on main thread if needed, but NotificationManager is thread-safe
        notifyUpdated()
      } catch (e: Exception) {
        e.printStackTrace()
        // Still notify without new image
        notifyUpdated()
      }
    }
  }

  private fun notifyUpdated() {
    val manager = getSystemService(NotificationManager::class.java)
    manager?.notify(NOTIFICATION_ID, buildNotification())
  }

  private inner class MediaSessionCallback : MediaSessionCompat.Callback() {
    override fun onPlay() = sendCommandToFlutter("play")
    override fun onPause() = sendCommandToFlutter("pause")
    override fun onSkipToNext() = sendCommandToFlutter("next")
    override fun onSkipToPrevious() = sendCommandToFlutter("previous")
  }

  override fun onDestroy() {
    executorService.shutdown()
    mediaSession.release()
    stopForeground(STOP_FOREGROUND_REMOVE)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null
}
