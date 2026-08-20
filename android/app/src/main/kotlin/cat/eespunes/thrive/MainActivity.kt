package cat.eespunes.thrive

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val deviceCalendarChannel = "cat.eespunes.thrive/device_calendar"
    private val calendarPermissionRequest = 8417
    private val thriveAccountName = "Thrive"
    private val thriveAccountType = "cat.eespunes.thrive.calendar"
    private val thriveCalendarName = "Thrive"

    private var pendingSyncArgs: Map<*, *>? = null
    private var pendingSyncResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceCalendarChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncThriveCalendar" -> syncThriveCalendar(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun syncThriveCalendar(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        if (!hasCalendarPermissions()) {
            pendingSyncArgs = args
            pendingSyncResult = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(
                    arrayOf(
                        Manifest.permission.READ_CALENDAR,
                        Manifest.permission.WRITE_CALENDAR,
                    ),
                    calendarPermissionRequest,
                )
            } else {
                result.success(mapOf("permissionGranted" to false, "synced" to 0))
            }
            return
        }
        runCalendarSync(args, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != calendarPermissionRequest) return
        val result = pendingSyncResult ?: return
        val args = pendingSyncArgs ?: emptyMap<String, Any?>()
        pendingSyncArgs = null
        pendingSyncResult = null
        if (hasCalendarPermissions()) {
            runCalendarSync(args, result)
        } else {
            result.success(mapOf("permissionGranted" to false, "synced" to 0))
        }
    }

    private fun runCalendarSync(args: Map<*, *>, result: MethodChannel.Result) {
        try {
            val calendarId = findOrCreateThriveCalendar()
            clearThriveCalendar(calendarId)
            val events = args["events"] as? List<*> ?: emptyList<Any?>()
            var inserted = 0
            for (rawEvent in events) {
                val event = rawEvent as? Map<*, *> ?: continue
                if (insertThriveEvent(calendarId, event)) inserted++
            }
            result.success(mapOf("permissionGranted" to true, "synced" to inserted))
        } catch (e: Exception) {
            result.error("device_calendar_sync_failed", e.message, null)
        }
    }

    private fun hasCalendarPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun findOrCreateThriveCalendar(): Long {
        findThriveCalendar()?.let { calendarId ->
            ensureThriveCalendarVisible(calendarId)
            return calendarId
        }

        val values = ContentValues().apply {
            put(Calendars.ACCOUNT_NAME, thriveAccountName)
            put(Calendars.ACCOUNT_TYPE, thriveAccountType)
            put(Calendars.NAME, thriveCalendarName)
            put(Calendars.CALENDAR_DISPLAY_NAME, thriveCalendarName)
            put(Calendars.CALENDAR_COLOR, 0xff0e9a8d.toInt())
            put(Calendars.CALENDAR_ACCESS_LEVEL, Calendars.CAL_ACCESS_OWNER)
            put(Calendars.OWNER_ACCOUNT, thriveAccountName)
            put(Calendars.VISIBLE, 1)
            put(Calendars.SYNC_EVENTS, 1)
            put(Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
        }
        val created = contentResolver.insert(syncAdapterCalendarUri(), values)
            ?: throw IllegalStateException("Could not create Thrive calendar")
        return ContentUris.parseId(created)
    }

    private fun findThriveCalendar(): Long? {
        val projection = arrayOf(Calendars._ID)
        val selection = "${Calendars.ACCOUNT_NAME}=? AND ${Calendars.ACCOUNT_TYPE}=?"
        val args = arrayOf(thriveAccountName, thriveAccountType)
        contentResolver.query(Calendars.CONTENT_URI, projection, selection, args, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) return cursor.getLong(0)
            }
        return null
    }

    private fun ensureThriveCalendarVisible(calendarId: Long) {
        val values = ContentValues().apply {
            put(Calendars.CALENDAR_DISPLAY_NAME, thriveCalendarName)
            put(Calendars.VISIBLE, 1)
            put(Calendars.SYNC_EVENTS, 1)
        }
        contentResolver.update(
            ContentUris.withAppendedId(Calendars.CONTENT_URI, calendarId),
            values,
            null,
            null,
        )
    }

    private fun clearThriveCalendar(calendarId: Long) {
        contentResolver.delete(
            Events.CONTENT_URI,
            "${Events.CALENDAR_ID}=?",
            arrayOf(calendarId.toString()),
        )
    }

    private fun insertThriveEvent(calendarId: Long, event: Map<*, *>): Boolean {
        val title = event["title"]?.toString()?.trim().orEmpty()
        val date = event["date"]?.toString()?.trim().orEmpty()
        if (title.isEmpty() || date.isEmpty()) return false

        val allDay = event["allDay"] == true
        val values = ContentValues().apply {
            put(Events.CALENDAR_ID, calendarId)
            put(Events.TITLE, title)
            put(Events.EVENT_LOCATION, event["location"]?.toString().orEmpty())
            put(Events.DESCRIPTION, event["notes"]?.toString().orEmpty())
            put(Events.ALL_DAY, if (allDay) 1 else 0)
            put(Events.AVAILABILITY, Events.AVAILABILITY_BUSY)
            put(Events.CUSTOM_APP_PACKAGE, packageName)
            put(Events.CUSTOM_APP_URI, "thrive://calendar/${event["id"] ?: ""}")
            if (allDay) {
                val start = parseDate(date)
                val end = parseOptionalDate(event["endDate"]?.toString())?.takeIf {
                    !it.isBefore(start)
                } ?: start
                put(Events.DTSTART, start.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
                put(Events.DTEND, end.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
                put(Events.EVENT_TIMEZONE, "UTC")
                put(Events.EVENT_END_TIMEZONE, "UTC")
            } else {
                val zone = ZoneId.systemDefault()
                val startDate = parseDate(date)
                val startTime = parseTime(event["start"]?.toString()) ?: LocalTime.of(9, 0)
                val start = startDate.atTime(startTime)
                val rawEndTime = parseTime(event["end"]?.toString()) ?: startTime.plusHours(1)
                val endDate = parseOptionalDate(event["endDate"]?.toString())?.takeIf {
                    !it.isBefore(startDate)
                } ?: startDate
                var end = endDate.atTime(rawEndTime)
                if (!end.isAfter(start)) end = start.plusHours(1)
                put(Events.DTSTART, start.atZone(zone).toInstant().toEpochMilli())
                put(Events.DTEND, end.atZone(zone).toInstant().toEpochMilli())
                put(Events.EVENT_TIMEZONE, zone.id)
                put(Events.EVENT_END_TIMEZONE, zone.id)
            }
        }
        return contentResolver.insert(Events.CONTENT_URI, values) != null
    }

    private fun syncAdapterCalendarUri(): Uri =
        Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(Calendars.ACCOUNT_NAME, thriveAccountName)
            .appendQueryParameter(Calendars.ACCOUNT_TYPE, thriveAccountType)
            .build()

    private fun parseDate(value: String?): LocalDate =
        try {
            LocalDate.parse(value)
        } catch (_: Exception) {
            LocalDate.now()
        }

    private fun parseOptionalDate(value: String?): LocalDate? =
        try {
            if (value.isNullOrBlank()) null else LocalDate.parse(value)
        } catch (_: Exception) {
            null
        }

    private fun parseTime(value: String?): LocalTime? =
        try {
            if (value.isNullOrBlank()) null else LocalTime.parse(value)
        } catch (_: Exception) {
            null
        }
}
