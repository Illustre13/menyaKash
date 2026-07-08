package com.imomo.i_momo

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation requires a FragmentActivity host to show the
// biometric/PIN/pattern prompt (spec Phase 5 Security Setup).
class MainActivity : FlutterFragmentActivity()
