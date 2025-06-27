package com.example.nfc_phone_pay


import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class MyHostApduService : HostUpdateService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        // Example: simple APDU response (SW 0x9000)
        return byteArrayOf(0x90.toByte(), 0x00.toByte())
    }

    override fun onDeactivated(reason: Int) {}
}