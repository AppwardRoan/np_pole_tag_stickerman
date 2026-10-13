package com.example.np_pole_tag_stickerman

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android shades the strips behind the status bar and the three buttons on
    // its own, and from Android 15 it ignores the colours Flutter asks for -
    // `systemNavigationBarColor` and `statusBarColor` do nothing there. The
    // shade is what put a dark band above the green header and another one
    // under the Scan button.
    //
    // Turning contrast enforcement off hands both strips back to the app: they
    // go transparent, and whatever the screen paints underneath is what shows.
    // The icons are still Flutter's to set, which it does in `main.dart`.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }
}
