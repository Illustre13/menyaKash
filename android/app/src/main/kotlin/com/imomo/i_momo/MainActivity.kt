package com.imomo.i_momo

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation requires a FragmentActivity host to show the
// biometric/PIN/pattern prompt (spec Phase 5 Security Setup).
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // "Pay now": initiate a USSD call directly via ACTION_CALL, so
        // Android runs the *182...# code and shows the network's own
        // response dialog — instead of only pre-filling the dialer and
        // making the user press call. Requires the CALL_PHONE runtime
        // permission, which the Dart side checks/requests BEFORE
        // invoking this (a SecurityException here means it didn't —
        // fail soft, the Dart side falls back to dialer pre-fill).
        // This never reads or automates the USSD session itself.
        //
        // "listSims"/"dialUssd" with a simSlotIndex (spec #7 SIM
        // chooser): a real dual-SIM device may have MTN on one SIM and
        // Airtel on the other, so which SIM actually dials matters for
        // whether the USSD code even reaches the right network. Uses
        // TelecomManager's PhoneAccountHandles (the same mechanism the
        // system dialer itself uses for SIM selection), never a
        // third-party SIM-management library.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "menyakash/ussd")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listSims" -> result.success(listSims())
                    "dialUssd" -> {
                        val code = call.argument<String>("code")
                        if (code == null) {
                            result.error("missing-arg", "dialUssd requires a 'code' argument", null)
                            return@setMethodCallHandler
                        }
                        val simSlotIndex = call.argument<Int>("simSlotIndex")
                        try {
                            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:" + Uri.encode(code)))
                            val handle = simSlotIndex?.let { phoneAccountHandleForSlot(it) }
                            if (handle != null) {
                                intent.putExtra(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: SecurityException) {
                            result.success(false)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Every callable phone-account SIM slot on this device, as plain
    /// maps (slotIndex, displayName, carrierName) — the Dart side never
    /// touches a native handle directly, only ever a slotIndex it hands
    /// back verbatim to dialUssd. Empty list (not an error) on any
    /// permission/API gap: the caller falls back to "just dial, let
    /// Android ask" when there's nothing to choose between.
    private fun listSims(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
        return try {
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val activeSubscriptions = try {
                subscriptionManager.activeSubscriptionInfoList ?: emptyList()
            } catch (e: SecurityException) {
                emptyList()
            }
            val handles = try {
                telecomManager.callCapablePhoneAccounts
            } catch (e: SecurityException) {
                return emptyList()
            }

            handles.mapIndexedNotNull { index, handle ->
                val account = try {
                    telecomManager.getPhoneAccount(handle)
                } catch (e: SecurityException) {
                    null
                } ?: return@mapIndexedNotNull null
                val subscriptionInfo = activeSubscriptions.getOrNull(index)
                mapOf(
                    "simSlotIndex" to index,
                    "displayName" to account.label?.toString(),
                    "carrierName" to (subscriptionInfo?.carrierName?.toString()
                        ?: account.label?.toString()),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun phoneAccountHandleForSlot(simSlotIndex: Int): PhoneAccountHandle? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return try {
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecomManager.callCapablePhoneAccounts.getOrNull(simSlotIndex)
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }
}
