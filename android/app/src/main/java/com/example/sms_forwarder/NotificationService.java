package com.example.sms_forwarder;

import android.content.Intent;
import android.provider.Settings;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import android.content.Context;

public class NotificationService extends NotificationListenerService {
    private static final String TAG = "NotificationService";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "🚀 Notification Listener Service Started!");
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        String notificationText = sbn.getNotification().tickerText != null ? sbn.getNotification().tickerText.toString() : "No ticker text";
        Log.d(TAG, "📩 إشعار جديد: " + notificationText);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        String notificationText = sbn.getNotification().tickerText != null ? sbn.getNotification().tickerText.toString() : "No ticker text";
        Log.d(TAG, "❌ إشعار محذوف: " + notificationText);
    }

    // ✅ إضافة وظيفة لفتح إعدادات الإشعارات في حالة عدم منح الإذن
    public static void requestNotificationPermission(Context context) {
        Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}
