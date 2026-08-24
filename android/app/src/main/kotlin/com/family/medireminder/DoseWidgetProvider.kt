package com.family.medireminder

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class DoseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.dose_widget)

            val widgetData = HomeWidgetPlugin.getData(context)

            val medicineName = widgetData?.getString("widget_medicine_name", "") ?: ""
            val doseInfo = widgetData?.getString("widget_dose_info", "") ?: ""
            val doseTime = widgetData?.getString("widget_dose_time", "") ?: ""
            val statusText = widgetData?.getString("widget_status_text", "") ?: ""
            val allDone = widgetData?.getBoolean("widget_all_done", false) ?: false

            if (allDone || medicineName.isEmpty()) {
                views.setViewVisibility(R.id.medicine_name, View.GONE)
                views.setViewVisibility(R.id.dose_info, View.GONE)
                views.setViewVisibility(R.id.dose_time, View.GONE)
                views.setViewVisibility(R.id.dose_status, View.GONE)
                views.setViewVisibility(R.id.time_icon, View.GONE)
                views.setViewVisibility(R.id.all_done_text, View.VISIBLE)

                if (medicineName.isEmpty() && !allDone) {
                    views.setTextViewText(R.id.all_done_text, "Add a medicine to get started 💊")
                } else {
                    views.setTextViewText(R.id.all_done_text, "✅ All done today!")
                }
            } else {
                views.setViewVisibility(R.id.medicine_name, View.VISIBLE)
                views.setViewVisibility(R.id.dose_info, View.VISIBLE)
                views.setViewVisibility(R.id.dose_time, View.VISIBLE)
                views.setViewVisibility(R.id.dose_status, View.VISIBLE)
                views.setViewVisibility(R.id.time_icon, View.VISIBLE)
                views.setViewVisibility(R.id.all_done_text, View.GONE)

                views.setTextViewText(R.id.medicine_name, medicineName)
                views.setTextViewText(R.id.dose_info, doseInfo)
                views.setTextViewText(R.id.dose_time, doseTime)
                views.setTextViewText(R.id.dose_status, statusText)
            }

            // Tap widget → open app
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
