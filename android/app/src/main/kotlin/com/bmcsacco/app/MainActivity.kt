package com.miasacco.appname

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's BiometricPrompt requires a FragmentActivity host. Extending the
// plain FlutterActivity makes authenticate() throw no_fragment_activity (which the
// service swallows), surfacing to the user as "Biometric verification failed".
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        splash.setKeepOnScreenCondition { false }
        super.onCreate(savedInstanceState)
    }
}
