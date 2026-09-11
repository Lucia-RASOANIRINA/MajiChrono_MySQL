package mg.majichrono.majichrono

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Point d'entree Android.
 *
 * Porte l'unique canal natif de l'application : la pose de `FLAG_SECURE`
 * (EXI-SEC06). Tout le reste passe par des plugins existants — un canal
 * maison est une surface a maintenir a chaque version d'Android, et on n'en
 * ouvre un que lorsqu'aucun plugin ne fait l'affaire.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "mg.majichrono/secure"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        setSecure(secure)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * `FLAG_SECURE` interdit la capture d'ecran **et** noircit l'apercu dans
     * les applications recentes. Il est retire des que l'ecran sensible est
     * quitte : le laisser en place noircirait l'apercu de toute
     * l'application, y compris sur des ecrans qui n'ont rien a proteger.
     */
    private fun setSecure(secure: Boolean) {
        runOnUiThread {
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}
