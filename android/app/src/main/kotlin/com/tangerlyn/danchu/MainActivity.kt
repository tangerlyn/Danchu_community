package com.tangerlyn.danchu

import android.content.Intent
import android.os.Bundle
import com.naver.maps.map.NaverMapSdk
import com.navercorp.nid.NaverIdLoginSDK
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        NaverMapSdk.getInstance(this).client =
            NaverMapSdk.NcpKeyClient("4erd0jhvuv")


        NaverIdLoginSDK.initialize(
            this,
            "LJqGXsYGZimOMYB1NyDO",
            "G9ZtyDl8Um",
            "단추모임"
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
