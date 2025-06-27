import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'dart:convert'; // For utf8.encode
import 'dart:typed_data'; // For Uint8List

class CardShareScreen extends StatelessWidget {
  final String cardData; // The virtual card info to share (JSON-encoded)

  const CardShareScreen({super.key, required this.cardData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Virtual Card')),
      backgroundColor: const Color(0xFF1A1D21),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code Sharing
            const Text(
              'Share via QR Code',
              style: TextStyle(
                  color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            QrImageView(
              data: cardData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 32),
            // NFC Sharing
            ElevatedButton.icon(
              icon: const Icon(Icons.nfc),
              label: const Text('Share via NFC'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                try {
                  // Check NFC availability
                  var availability = await FlutterNfcKit.nfcAvailability;
                  if (availability != NFCAvailability.available) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('NFC not available on this device!')),
                    );
                    return;
                  }

                  // Create an NDEF text record manually
                  final payload = utf8.encode(cardData);
                  final ndefRecord = <int>[
                    0xD1, // NDEF record header (TNF=1, MB=1, ME=1)
                    0x01, // Type length (1 byte for 'T')
                    payload.length + 3, // Payload length (payload + status byte + language code)
                    0x54, // Type 'T' for text
                    0x02, // Status byte (UTF-8, language code length=2)
                    ...utf8.encode('en'), // Language code 'en'
                    ...payload, // Actual text payload
                  ];

                  // Wrap in an NDEF message (TLV format for NTAG)
                  final ndefMessage = <int>[
                    0x03, // NDEF TLV tag
                    ndefRecord.length, // Length of NDEF record
                    ...ndefRecord, // NDEF record
                    0xFE, // Terminator TLV
                  ];

                  // Poll for an NFC tag
                  var tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 10));

                  // Write the NDEF message using transceive (for NTAG21x or Ultralight)
                  if (tag.type == NFCTagType.mifare_ultralight) {
                    // Write to block 4 onwards (assuming NTAG21x, adjust for other tags)
                    final blockSize = 4;
                    int block = 4;
                    for (int i = 0; i < ndefMessage.length; i += blockSize, block++) {
                      final chunk = ndefMessage.sublist(i, i + blockSize > ndefMessage.length ? ndefMessage.length : i + blockSize);
                      // Pad chunk to 4 bytes if necessary
                      while (chunk.length < blockSize) {
                        chunk.add(0x00);
                      }
                      final writeCommand = <int>[
                        0xA2, // WRITE command
                        block, // Block number
                        ...chunk,
                      ];
                      await FlutterNfcKit.transceive(Uint8List.fromList(writeCommand));
                    }
                  } else {
                    throw Exception('Unsupported tag type: ${tag.type}');
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card shared over NFC')),
                  );

                  // Finish NFC session
                  await FlutterNfcKit.finish();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('NFC error: $e')),
                  );
                  await FlutterNfcKit.finish(); // Ensure session is closed on error
                }
              },
            ),
            const SizedBox(height: 24),
            // Bluetooth Sharing (placeholder)
            ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth),
              label: const Text('Share via Bluetooth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('Bluetooth Sharing'),
                    content: Text('Bluetooth sharing coming soon!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}