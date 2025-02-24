package com.example.sms_forwarder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import android.util.Log;
import android.content.SharedPreferences;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;

import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.telephony.TelephonyManager;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class SmsReceiver extends BroadcastReceiver {
    private static final String TAG = "SmsReceiver";
    private static final String CHANNEL = "sms_forwarder";
    private static FlutterEngine flutterEngine;
    private static Context appContext;

    public SmsReceiver() {
        // Default constructor
    }

    public static void setFlutterEngine(FlutterEngine engine, Context context) {
        flutterEngine = engine;
        appContext = context;
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler(new MethodCallHandler() {
            @Override
            public void onMethodCall(MethodCall call, Result result) {
                if (call.method.equals("fetchAllSms")) {
                    fetchAllSms(appContext, result);
                } else {
                    result.notImplemented();
                }
            }
        });
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION.equals(intent.getAction())) {
            Bundle bundle = intent.getExtras();
            if (bundle != null) {
                StringBuilder messageBodyBuilder = new StringBuilder();
                String sender = null;

                for (SmsMessage smsMessage : Telephony.Sms.Intents.getMessagesFromIntent(intent)) {
                    if (sender == null) {
                        sender = smsMessage.getOriginatingAddress();
                    }
                    messageBodyBuilder.append(smsMessage.getMessageBody());
                }

                String messageBody = messageBodyBuilder.toString();
                String receiver = getSimNumber(context); // ✅ استخراج رقم الهاتف الفعلي للـ SIM

                Log.d(TAG, "📩 استلام رسالة من: " + sender + " - المحتوى: " + messageBody + " - 📥 المستقبل: " + receiver);

                // تخزين الرسالة في SharedPreferences
                saveSmsToStorage(context, sender, messageBody, receiver);

                // إرسال الرسالة إلى Flutter
                if (flutterEngine != null) {
                    Map<String, String> smsData = new HashMap<>();
                    smsData.put("sender", sender);
                    smsData.put("message", messageBody);
                    smsData.put("receiver", receiver);

                    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                            .invokeMethod("onSmsReceived", smsData);
                } else {
                    Log.w(TAG, "FlutterEngine is not set. Message stored in SharedPreferences.");
                }

                if (!isMessageDuplicate(context, sender, messageBody, receiver)) {
                    saveLastSentMessage(context, sender, messageBody, receiver);
                    // Send message to API
                    // Implement API call here
                }
            }
        }
    }

    private static String getSimNumber(Context context) {
        TelephonyManager telephonyManager = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
        if (telephonyManager != null) {
            String simNumber = telephonyManager.getLine1Number();
            if (simNumber != null && !simNumber.isEmpty()) {
                return simNumber;
            }
        }

        // ✅ محاولة جلب الرقم من SubscriptionManager إذا كان الجهاز يدعم أكثر من شريحة SIM
        SubscriptionManager subscriptionManager = (SubscriptionManager) context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
        if (subscriptionManager != null) {
            List<SubscriptionInfo> subscriptionInfoList = subscriptionManager.getActiveSubscriptionInfoList();
            if (subscriptionInfoList != null && !subscriptionInfoList.isEmpty()) {
                for (SubscriptionInfo info : subscriptionInfoList) {
                    String simNumber = info.getNumber();
                    if (simNumber != null && !simNumber.isEmpty()) {
                        return simNumber;
                    }
                }
            }
        }

        // ✅ إذا لم يتم العثور على رقم، يتم إرجاع `+201000000000`
        return "+201000000000";
    }

    private void saveSmsToStorage(Context context, String sender, String message, String receiver) {
        SharedPreferences prefs = context.getSharedPreferences("sms_forwarder_prefs", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("last_sms_sender", sender);
        editor.putString("last_sms_message", message);
        editor.putString("last_sms_receiver", receiver);
        editor.apply();
    }

    private void saveLastSentMessage(Context context, String sender, String message, String receiver) {
        SharedPreferences prefs = context.getSharedPreferences("sms_forwarder_prefs", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("last_sent_sender", sender);
        editor.putString("last_sent_message", message);
        editor.putString("last_sent_receiver", receiver);
        editor.apply();
    }

    private boolean isMessageDuplicate(Context context, String sender, String message, String receiver) {
        SharedPreferences prefs = context.getSharedPreferences("sms_forwarder_prefs", Context.MODE_PRIVATE);
        String lastSender = prefs.getString("last_sent_sender", "");
        String lastMessage = prefs.getString("last_sent_message", "");
        String lastReceiver = prefs.getString("last_sent_receiver", "");
        return sender.equals(lastSender) && message.equals(lastMessage) && receiver.equals(lastReceiver);
    }

    private static void fetchAllSms(Context context, Result result) {
        List<Map<String, String>> smsList = new ArrayList<>();
        Uri uri = Uri.parse("content://sms/inbox");
        Cursor cursor = context.getContentResolver().query(uri, null, null, null, null);

        if (cursor != null && cursor.moveToFirst()) {
            do {
                String sender = cursor.getString(cursor.getColumnIndexOrThrow("address"));
                String message = cursor.getString(cursor.getColumnIndexOrThrow("body"));
                String dateReceived = cursor.getString(cursor.getColumnIndexOrThrow("date"));
                String receiver = getSimNumber(context); // ✅ استخراج رقم الهاتف الصحيح

                Map<String, String> sms = new HashMap<>();
                sms.put("sender", sender);
                sms.put("content", message);
                sms.put("receiver", receiver);
                sms.put("date_received", dateReceived);
                sms.put("status", "old");

                smsList.add(sms);
            } while (cursor.moveToNext());

            cursor.close();
        }

        result.success(smsList);
    }
}
