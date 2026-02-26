package com.thrive.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

class NativeSplashActivity : Activity() {
  private val splashHandler = Handler(Looper.getMainLooper())

  override fun onCreate(savedInstanceState: Bundle?) {
    setTheme(R.style.NormalTheme)
    super.onCreate(savedInstanceState)
    setContentView(R.layout.native_splash)

    splashHandler.postDelayed(
      {
        startActivity(Intent(this, MainActivity::class.java))
        overridePendingTransition(0, 0)
        finish()
      },
      splashHoldMillis,
    )
  }

  override fun onDestroy() {
    splashHandler.removeCallbacksAndMessages(null)
    super.onDestroy()
  }

  companion object {
    private const val splashHoldMillis = 150L
  }
}
