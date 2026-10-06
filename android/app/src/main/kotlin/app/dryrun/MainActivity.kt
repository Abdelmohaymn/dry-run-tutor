package app.dryrun

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val trustedTimeChannel = TrustedTimeChannel(this)
    private val deviceIdChannel = DeviceIdChannel(this)
    private val onDeviceRecognizerCheck = OnDeviceRecognizerCheck(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        trustedTimeChannel.attach(flutterEngine.dartExecutor.binaryMessenger)
        deviceIdChannel.attach(flutterEngine.dartExecutor.binaryMessenger)
        onDeviceRecognizerCheck.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        trustedTimeChannel.detach()
        deviceIdChannel.detach()
        onDeviceRecognizerCheck.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
