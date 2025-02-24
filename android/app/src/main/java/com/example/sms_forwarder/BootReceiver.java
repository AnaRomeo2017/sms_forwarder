package com.example.sms_forwarder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            Log.d("BootReceiver", "✅ الجهاز أعيد تشغيله - تشغيل الخدمة في الخلفية.");

            // ✅ تشغيل التطبيق تلقائيًا بعد إعادة التشغيل
            Intent startIntent = new Intent(context, MainActivity.class);
            startIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(startIntent);

            // ✅ تشغيل خدمة الخلفية (إذا كنت تستخدمها)
            Intent serviceIntent = new Intent(context, BackgroundService.class);
            context.startService(serviceIntent);
        }
    }
}
