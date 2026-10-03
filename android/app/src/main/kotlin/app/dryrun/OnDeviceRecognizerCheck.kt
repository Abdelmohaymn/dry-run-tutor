package app.dryrun

import android.content.Context
import android.os.Build
import android.speech.SpeechRecognizer
import java.util.Locale
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * research.md R-002: on-device recognition is what turns "audio never
 * leaves the device" into a guarantee rather than a preference, and
 * `speech_to_text`'s own `initialize()` collapses "no recognizer at all"
 * and "recognizer present, on-device language pack missing" into the same
 * `false` — which is not enough for `RecognitionServiceImpl.availability()`
 * to tell FR-011a's two cases apart (`unsupported` vs `needsLanguagePack`).
 * This probes `SpeechRecognizer.isOnDeviceRecognitionAvailable` directly.
 *
 * Only `recognitionAvailable` is acted on now: the app binds the platform's
 * *default* recognition service, which needs no language pack, so on-device
 * availability no longer decides whether the mic works.
 */
class OnDeviceRecognizerCheck(private val context: Context) : MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        private const val CHANNEL_NAME = "app.dryrun/on_device_recognizer"
        private const val METHOD_CHECK = "isOnDeviceRecognitionAvailable"
        private const val METHOD_DEVICE_LOCALES = "deviceLocales"
        private const val METHOD_ALL_LOCALES = "allLocales"
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
            METHOD_CHECK -> result.success(check())
            METHOD_DEVICE_LOCALES -> result.success(deviceLocales())
            METHOD_ALL_LOCALES -> result.success(allLocales())
            else -> result.notImplemented()
        }
    }

    /**
     * Resolves with a map of:
     *  - `recognitionAvailable` (bool): whether any `RecognitionService`
     *    exists on the device at all.
     *  - `onDeviceAvailable` (bool): whether on-device recognition
     *    specifically is available. `false` whenever `recognitionAvailable`
     *    is `false` — there is nothing to check on-device support of.
     */
    private fun check(): Map<String, Boolean> {
        val recognitionAvailable = SpeechRecognizer.isRecognitionAvailable(context)
        // isOnDeviceRecognitionAvailable is API 31+; older devices have no on-device recognizer.
        val onDeviceAvailable = if (recognitionAvailable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } else {
            false
        }
        return mapOf(
            "recognitionAvailable" to recognitionAvailable,
            "onDeviceAvailable" to onDeviceAvailable,
        )
    }

    /**
     * The languages the learner has configured this device for, newest
     * preference first, with a display name for each.
     *
     * FR-011b needs these because `speech_to_text`'s `locales()` is an
     * incomplete claim: on this device it omits Arabic entirely, yet
     * `ar-EG` recognises Arabic perfectly when asked for by name (verified
     * on device, 2026-08-28). A picker built only from that list would
     * never offer an Arabic speaker their own language.
     */
    private fun deviceLocales(): List<Map<String, String>> {
        val configured = context.resources.configuration.locales
        val display = Locale.getDefault()
        return (0 until configured.size()).map { index ->
            val locale = configured[index]
            mapOf(
                "localeId" to locale.toLanguageTag(),
                "name" to locale.getDisplayName(display),
            )
        }
    }

    /**
     * Every locale the platform knows, for FR-011b's search.
     *
     * Offered in full rather than filtered to what the recogniser claims to
     * support, because that claim is demonstrably incomplete. Asking for a
     * language the recogniser cannot do is not a silent failure — it lands
     * on FR-011a's `languageUnavailable` screen, which says so.
     *
     * Restricted to locales that name both a language and a country: a bare
     * language has no region for the recogniser to pick a model from, and
     * the variants (script, extension) are noise in a picker.
     */
    private fun allLocales(): List<Map<String, String>> {
        val display = Locale.getDefault()
        return Locale.getAvailableLocales()
            .filter { it.language.isNotEmpty() && it.country.isNotEmpty() && it.variant.isEmpty() }
            .map { mapOf("localeId" to it.toLanguageTag(), "name" to it.getDisplayName(display)) }
            .distinctBy { it["localeId"] }
            .sortedBy { it["name"] }
    }
}
