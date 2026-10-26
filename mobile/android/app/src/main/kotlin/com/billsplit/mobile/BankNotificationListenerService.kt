package com.billsplit.mobile

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class BankNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "BankNotifListener"
        const val ACTION_BANK_NOTIFICATION = "com.billsplit.app.BANK_NOTIFICATION"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_TIMESTAMP = "timestamp"

        // Danh sách các package app ngân hàng phổ biến tại Việt Nam
        val BANK_PACKAGES = setOf(
            "com.vcb", // Vietcombank
            "com.mbmobile", // MBBank
            "vn.com.techcombank.bb.app", // Techcombank Mobile
            "com.techcombank", // Techcombank
            "com.vpbank.onlinebanking", // VPBank NEO
            "com.vnpay.bidv", // BIDV SmartBanking
            "mobile.acb.com.vn", // ACB ONE
            "com.vnpay.agribank", // Agribank E-Mobile
            "com.tpbank.tpbmo", // TPBank
            "com.msb.digital", // MSB mBank
            "vn.com.scb.mbanking", // SCB
            "com.shb.mobile", // SHB Mobile
            "com.hdbank.mbank", // HDBank
            "com.vnpay.sacombank", // Sacombank Pay
            "vn.momo.platform", // MoMo
            "com.vng.zalopay" // ZaloPay
        )

        // Từ khóa nhận diện biến động số dư / thanh toán
        val PAYMENT_KEYWORDS = listOf(
            "SD", "Số dư", "TK", "GD", "VND", "VND+", "VND-", "BS", "NAPAS", "biến động"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val extras = sbn.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val content = if (bigText.isNotEmpty()) bigText else text

        // Kiểm tra xem thông báo có xuất phát từ app ngân hàng hoặc chứa từ khóa tài chính
        val isBankApp = BANK_PACKAGES.contains(packageName)
        val hasPaymentKeyword = PAYMENT_KEYWORDS.any { keyword ->
            title.contains(keyword, ignoreCase = true) || content.contains(keyword, ignoreCase = true)
        }

        if (isBankApp || hasPaymentKeyword) {
            Log.d(TAG, "Bắt được thông báo ngân hàng [$packageName]: $title - $content")

            val intent = Intent(ACTION_BANK_NOTIFICATION).apply {
                putExtra(EXTRA_PACKAGE, packageName)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, content)
                putExtra(EXTRA_TIMESTAMP, sbn.postTime)
                setPackage(this@BankNotificationListenerService.packageName)
            }
            sendBroadcast(intent)

            // Gọi trực tiếp MainActivity nếu đang chạy
            MainActivity.onBankNotificationReceived(packageName, title, content)
        }
    }
}
