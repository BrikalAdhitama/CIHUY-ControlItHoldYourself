package com.cihuy.app

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "cihuy/exact_alarm"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "checkExactAlarmAllowed" -> {
          val allowed = isExactAlarmAllowed()
          result.success(allowed)
        }
        "requestExactAlarmPermission" -> {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!isExactAlarmAllowed()) {
              try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                // set data package to encourage direct settings for this app
                intent.data = Uri.parse("package:$packageName")
                // start as activity (user will interact)
                startActivity(intent)
                result.success(true) // we opened screen — return true to indicate we attempted
              } catch (e: Exception) {
                // fallback: open app settings
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.success(false)
              }
            } else {
              result.success(true) // already allowed
            }
          } else {
            result.success(true) // older OS, no explicit request needed
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun isExactAlarmAllowed(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
      return am.canScheduleExactAlarms()
    }
    return true
  }
}