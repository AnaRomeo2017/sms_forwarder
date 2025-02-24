package com.example.sms_forwarder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;

public class BackgroundService extends Service {
    private static final String TAG = "BackgroundService";
    private static final String CHANNEL_ID = "SMS_FORWARDER_SERVICE";
    private PowerManager.WakeLock wakeLock;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "🚀 Background Service Started!");
        startForegroundService();
        acquireWakeLock(); // ✅ منع إيقاف الخدمة عند إغلاق الشاشة
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "🔄 Service Restarted");
        return START_STICKY; // ✅ يضمن استمرار الخدمة حتى لو تم إغلاق التطبيق
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        Log.w(TAG, "⚠ التطبيق تم إغلاقه، سيتم إعادة تشغيل الخدمة...");
        Intent restartServiceIntent = new Intent(getApplicationContext(), BackgroundService.class);
        startService(restartServiceIntent);
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.w(TAG, "⛔ تم إيقاف الخدمة!");
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void startForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "SMS Forwarder Background Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }

            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle("SMS Forwarder يعمل في الخلفية")
                    .setContentText("استقبال وإعادة توجيه الرسائل يعمل بشكل مستمر")
                    .setSmallIcon(R.mipmap.ic_launcher) // ✅ تأكد من وجود هذا الأيقونة

                    // ✅ دعم Android 14+
                    .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE);

            startForeground(1, builder.build());
        }
    }

    private void acquireWakeLock() {
        PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
        if (powerManager != null) {
            wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "SMSForwarder::WakeLock"
            );
            wakeLock.acquire();
            Log.d(TAG, "🔋 WAKE_LOCK acquired!");
        }
    }
}
