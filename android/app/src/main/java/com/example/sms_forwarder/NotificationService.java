package com.example.sms_forwarder;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

public class NotificationService extends NotificationListenerService {
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        Log.d("NotificationService", "Notification received: " + sbn.getNotification().tickerText);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        Log.d("NotificationService", "Notification removed: " + sbn.getNotification().tickerText);
    }
}
