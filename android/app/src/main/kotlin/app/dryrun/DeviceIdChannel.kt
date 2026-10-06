package app.dryrun

import android.content.Context
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Hands the Dart side Android's per-app `Settings.Secure.ANDROID_ID`.
 *
 * Since Android 8 the value is scoped to (app signing key, user, device)
 * and survives uninstall, reinstall and "clear data", which is what lets
 * the relay recognise a returning phone and keep its free taster spent
 * (specs/006-lean-backend research.md R-1). It needs no permission.
 *
 * The raw value goes to `POST /v1/install` and nowhere else: the relay
 * stores only a keyed hash of it, and the app never persists or logs it.
 */
class DeviceIdChannel(private val context: Context) : MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        private const val CHANNEL_NAME = "app.dryrun/device_id"
        private const val METHOD_ANDROID_ID = "androidId"
    }

    fun attach(binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // May be null; the Dart side treats that as "no identity".
            METHOD_ANDROID_ID -> result.success(
                Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID),
            )
            else -> result.notImplemented()
        }
    }
}
