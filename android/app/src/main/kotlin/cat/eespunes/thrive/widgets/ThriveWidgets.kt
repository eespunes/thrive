package cat.eespunes.thrive.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.view.View
import android.widget.RemoteViews
import cat.eespunes.thrive.MainActivity
import cat.eespunes.thrive.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * Android home-screen widgets (epic #224), rendering the payload the Dart
 * side stores in the shared HomeWidget preferences. Design source:
 * docs/design/'Home & nav options.dc.html', Turn 3 (3a/3b).
 */
object ThriveWidgets {
  fun payload(widgetData: SharedPreferences): JSONObject? =
      widgetData.getString("payload", null)?.let {
        try {
          JSONObject(it)
        } catch (e: Exception) {
          null
        }
      }

  fun launch(context: Context, target: String, id: String? = null) =
      HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse("thrive://open?target=$target" + (id?.let { "&id=$it" } ?: "")),
      )

  fun background(context: Context, uri: String) =
      HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))

  /** Placement analytics (#250): drained + logged by the Dart side. */
  fun recordPlacement(context: Context, widgetId: String) {
    val prefs =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val existing = prefs.getString("placed_events", "") ?: ""
    prefs.edit().putString("placed_events", "$existing,$widgetId").apply()
  }

  /** Rough size-bucket re-flow (#251): rows the current height can hold. */
  fun heightBucket(options: Bundle?): Int {
    val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 110
    return if (h >= 220) 2 else if (h >= 100) 1 else 0
  }
}

abstract class ThriveWidgetProvider(private val widgetId: String) : HomeWidgetProvider() {
  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    ThriveWidgets.recordPlacement(context, widgetId)
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle?,
  ) {
    // Drag-resize re-flow (#251): re-render for the new size bucket.
    val prefs =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), prefs)
  }
}

/** 4×2 / 4×4 Money widget — keeps the Thrive gradient (#255). */
class MoneyWidgetProvider : ThriveWidgetProvider("money") {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val p = ThriveWidgets.payload(widgetData) ?: return
    val money = p.optJSONObject("money") ?: return
    val kid = p.optBoolean("kid")
    for (id in appWidgetIds) {
      val tall = ThriveWidgets.heightBucket(appWidgetManager.getAppWidgetOptions(id)) >= 2
      val views =
          RemoteViews(
              context.packageName,
              if (tall) R.layout.widget_money_large else R.layout.widget_money,
          )
      if (kid) {
        // Kid devices never show money (#257).
        views.setTextViewText(R.id.money_balance, "")
        views.setTextViewText(R.id.money_sub, context.getString(R.string.widget_kid_money))
        views.setTextViewText(R.id.money_due_label, "")
        views.setTextViewText(R.id.money_due, "")
      } else {
        views.setTextViewText(
            R.id.money_header, "THRIVE · " + money.optString("month").uppercase())
        views.setTextViewText(R.id.money_balance, money.optString("balance"))
        views.setTextViewText(
            R.id.money_sub, "projected · " + money.optString("stillToPay") + " still to pay")
        views.setTextViewText(R.id.money_due_label, context.getString(R.string.widget_due_today))
        views.setTextViewText(R.id.money_due, money.optString("dueToday"))
        views.setProgressBar(R.id.money_progress, 100, money.optInt("progress"), false)
      }
      views.setOnClickPendingIntent(R.id.money_root, ThriveWidgets.launch(context, "finance"))
      if (tall && !kid) bindBills(context, views, money)
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  /** 4×4: up to three next bills, the first payable in place (#252). */
  private fun bindBills(context: Context, views: RemoteViews, money: JSONObject) {
    val bills = money.optJSONArray("bills")
    val closed = money.optBoolean("closed")
    val rows =
        listOf(
            Triple(R.id.bill_row_1, Triple(R.id.bill_due_1, R.id.bill_label_1, R.id.bill_amount_1), R.id.bill_pay_1),
            Triple(R.id.bill_row_2, Triple(R.id.bill_due_2, R.id.bill_label_2, R.id.bill_amount_2), R.id.bill_pay_2),
            Triple(R.id.bill_row_3, Triple(R.id.bill_due_3, R.id.bill_label_3, R.id.bill_amount_3), R.id.bill_pay_3),
        )
    for ((i, row) in rows.withIndex()) {
      val (rowId, textIds, payId) = row
      val bill = if (bills != null && i < bills.length()) bills.optJSONObject(i) else null
      if (bill == null) {
        views.setViewVisibility(rowId, View.GONE)
        continue
      }
      views.setViewVisibility(rowId, View.VISIBLE)
      views.setTextViewText(textIds.first, bill.optString("due"))
      views.setTextViewText(textIds.second, bill.optString("label"))
      views.setTextViewText(textIds.third, bill.optString("amount"))
      if (closed || i > 0) {
        views.setViewVisibility(payId, View.GONE)
      } else {
        views.setViewVisibility(payId, View.VISIBLE)
        views.setOnClickPendingIntent(
            payId,
            ThriveWidgets.background(
                context,
                "thrive://act?do=pay_bill&year=" + money.optInt("year") +
                    "&month=" + Uri.encode(money.optString("monthKey")) +
                    "&cat=" + Uri.encode(bill.optString("cat")) +
                    "&id=" + Uri.encode(bill.optString("id")),
            ),
        )
      }
    }
  }
}

/** 2×2 (and wider) Today widget: events + first open to-do with a tick. */
class TodayWidgetProvider : ThriveWidgetProvider("today") {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val p = ThriveWidgets.payload(widgetData) ?: return
    val today = p.optJSONObject("today") ?: return
    val events = today.optJSONArray("events")
    val tasks = today.optJSONArray("tasks")
    for (id in appWidgetIds) {
      val bucket = ThriveWidgets.heightBucket(appWidgetManager.getAppWidgetOptions(id))
      val views = RemoteViews(context.packageName, R.layout.widget_today)
      val rowIds =
          listOf(
              Triple(R.id.today_row_1, R.id.today_title_1, R.id.today_time_1),
              Triple(R.id.today_row_2, R.id.today_title_2, R.id.today_time_2),
              Triple(R.id.today_row_3, R.id.today_title_3, R.id.today_time_3),
              Triple(R.id.today_row_4, R.id.today_title_4, R.id.today_time_4),
          )
      val visible = if (bucket >= 2) 4 else 2
      var shown = 0
      for ((i, row) in rowIds.withIndex()) {
        val ev = if (events != null && i < events.length()) events.optJSONObject(i) else null
        if (ev == null || i >= visible) {
          views.setViewVisibility(row.first, View.GONE)
          continue
        }
        shown++
        views.setViewVisibility(row.first, View.VISIBLE)
        views.setTextViewText(row.second, ev.optString("title"))
        views.setTextViewText(row.third, ev.optString("time"))
      }
      views.setViewVisibility(
          R.id.today_empty, if (shown == 0) View.VISIBLE else View.GONE)
      // First open task, tickable in place (#252).
      val task = if (tasks != null && tasks.length() > 0) tasks.optJSONObject(0) else null
      if (task == null) {
        views.setViewVisibility(R.id.today_task_row, View.GONE)
      } else {
        views.setViewVisibility(R.id.today_task_row, View.VISIBLE)
        views.setTextViewText(R.id.today_task_title, task.optString("title"))
        views.setOnClickPendingIntent(
            R.id.today_task_tick,
            ThriveWidgets.background(
                context,
                "thrive://act?do=tick_task&list=" + Uri.encode(task.optString("listId")) +
                    "&task=" + Uri.encode(task.optString("id")),
            ),
        )
      }
      views.setOnClickPendingIntent(R.id.today_root, ThriveWidgets.launch(context, "calendar"))
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}

/** 2×2 Loyalty card widget — also placeable on the keyguard (#258). */
class CardWidgetProvider : ThriveWidgetProvider("card") {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val p = ThriveWidgets.payload(widgetData)
    val card = p?.optJSONObject("card")
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_card)
      if (card == null) {
        views.setTextViewText(R.id.card_name, context.getString(R.string.widget_no_card))
        views.setTextViewText(R.id.card_hint, context.getString(R.string.widget_scan_hint))
        views.setViewVisibility(R.id.card_code, View.GONE)
        views.setOnClickPendingIntent(R.id.card_root, ThriveWidgets.launch(context, "scan"))
      } else {
        views.setTextViewText(R.id.card_name, card.optString("name"))
        views.setTextViewText(R.id.card_hint, card.optString("hint"))
        val b64 = widgetData.getString("card_code_b64", null)
        val bmp =
            b64?.let {
              try {
                val bytes = Base64.decode(it, Base64.DEFAULT)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
              } catch (e: Exception) {
                null
              }
            }
        if (bmp != null) {
          views.setViewVisibility(R.id.card_code, View.VISIBLE)
          views.setImageViewBitmap(R.id.card_code, bmp)
        } else {
          views.setViewVisibility(R.id.card_code, View.GONE)
        }
        views.setOnClickPendingIntent(
            R.id.card_root, ThriveWidgets.launch(context, "card", card.optString("id")))
      }
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}

/** 4×1 Quick actions — four independent deep links (#254). */
class QuickActionsWidgetProvider : ThriveWidgetProvider("quick_actions") {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val kid = ThriveWidgets.payload(widgetData)?.optBoolean("kid") ?: false
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_quick)
      views.setOnClickPendingIntent(
          R.id.quick_cost,
          ThriveWidgets.launch(context, if (kid) "home" else "cost"))
      views.setOnClickPendingIntent(R.id.quick_scan, ThriveWidgets.launch(context, "scan"))
      views.setOnClickPendingIntent(R.id.quick_event, ThriveWidgets.launch(context, "event"))
      views.setOnClickPendingIntent(R.id.quick_list, ThriveWidgets.launch(context, "shop"))
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}

/** 4×2 Shopping list — "+" opens the app on that list (#254). */
class ShoppingWidgetProvider : ThriveWidgetProvider("shopping") {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val p = ThriveWidgets.payload(widgetData)
    val shopping = p?.optJSONObject("shopping")
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_shopping)
      if (shopping == null) {
        views.setTextViewText(R.id.shop_name, context.getString(R.string.widget_no_list))
        views.setTextViewText(R.id.shop_left, "")
        views.setTextViewText(R.id.shop_items, "")
        views.setOnClickPendingIntent(R.id.shop_root, ThriveWidgets.launch(context, "tasks"))
      } else {
        val listId = shopping.optString("listId")
        views.setTextViewText(R.id.shop_name, shopping.optString("name"))
        views.setTextViewText(
            R.id.shop_left, shopping.optInt("left").toString() + " left")
        val items = shopping.optJSONArray("items")
        val labels = ArrayList<String>()
        if (items != null) for (i in 0 until items.length()) labels.add(items.optString(i))
        views.setTextViewText(R.id.shop_items, labels.joinToString("  ·  "))
        views.setOnClickPendingIntent(
            R.id.shop_root, ThriveWidgets.launch(context, "shopping", listId))
        views.setOnClickPendingIntent(
            R.id.shop_add, ThriveWidgets.launch(context, "shopping", listId))
      }
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
