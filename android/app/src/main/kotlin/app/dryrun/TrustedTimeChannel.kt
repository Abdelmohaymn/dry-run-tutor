package app.dryrun

import android.content.Context
import android.os.SystemClock
import com.google.android.gms.time.TrustedTime
import com.google.android.gms.time.TrustedTimeClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Tier one of `TrustedTimeSource`'s three-tier chain (research.md R-003):
 * Play Services TrustedTime, which stays correct offline once synced and
 * is immune to a learner (or a script kiddie chasing a streak) moving the
 * device clock by hand.
 *
 * `trusted_time_android` — the pub.dev package `design.md` originally
 * named — is discontinued, so this ~60-line channel owns the binding
 * directly instead of depending on it. See research.md R-003 for the full
 * rationale and the two alternatives that were rejected.
 *
 * The Dart side (`lib/core/time/trusted_time_source_impl.dart`) treats
 * "unavailable" (an exception from this channel, or `isTrusted == false`)
 * as tier one failing over to tier two (the relay's `Date:` header) —
 * never as a reason to fall back to `System.currentTimeMillis()`.
 */
class TrustedTimeChannel(private val context: Context) : MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        private const val CHANNEL_NAME = "app.dryrun/trusted_time"
        private const val METHOD_NOW = "now"
        private const val METHOD_ELAPSED_REALTIME = "elapsedRealtimeMillis"
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
            METHOD_NOW -> queryTrustedTime(result)
            METHOD_ELAPSED_REALTIME -> result.success(SystemClock.elapsedRealtime())
            else -> result.notImplemented()
        }
    }

    /**
     * Resolves with a map of:
     *  - `epochMillis` (Int64): the trusted instant, in UTC epoch millis.
     *  - `isTrusted` (bool): whether Play Services reports this reading as
     *    backed by a genuine trusted-time sync rather than a fallback.
     *  - `elapsedRealtimeMillis` (Int64): `SystemClock.elapsedRealtime()`
     *    at the moment of the reading, so the Dart side can anchor tier
     *    three (last known anchor + monotonic delta) off a real sample
     *    rather than off its own possibly-stale clock read.
     *
     * Rejects with error code `unavailable` if TrustedTime has never
     * synced (typically: no network since install) — the Dart side falls
     * back to the relay `Date:` header in that case, never to the device
     * clock.
     */
    private fun queryTrustedTime(result: Result) {
        TrustedTime.createClient(context)
            .addOnSuccessListener { client: TrustedTimeClient ->
                try {
                    // Nullable: null means the client has never completed a
                    // sync, which is exactly tier one "unavailable" — the
                    // Dart facade falls to tier two, never to the device
                    // wall clock.
                    val epochMillis = client.computeCurrentUnixEpochMillis()
                    if (epochMillis == null) {
                        result.error("unavailable", "TrustedTimeClient has not synced", null)
                        return@addOnSuccessListener
                    }
                    val elapsedRealtimeMillis = SystemClock.elapsedRealtime()
                    result.success(
                        mapOf(
                            "epochMillis" to epochMillis,
                            "isTrusted" to true,
                            "elapsedRealtimeMillis" to elapsedRealtimeMillis,
                        ),
                    )
                } catch (e: Exception) {
                    result.error("unavailable", "TrustedTimeClient could not compute a time", e.message)
                }
            }
            .addOnFailureListener { e ->
                // Most commonly: no sync has ever succeeded (offline since
                // install). The Dart facade falls to tier two, never to
                // the device wall clock.
                result.error("unavailable", "TrustedTime has not synced", e.message)
            }
    }
}
