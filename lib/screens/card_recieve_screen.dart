import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_phone_pay/services/card_dv_services.dart'; // Import CardDbService
import 'dart:convert'; // For jsonDecode and utf8.decode

class CardReceiveScreen extends StatefulWidget {
  const CardReceiveScreen({super.key});

  @override
  State<CardReceiveScreen> createState() => _CardReceiveScreenState();
}

class _CardReceiveScreenState extends State<CardReceiveScreen> {
  Map<String, dynamic>? receivedCard;
  String? nfcStatus;
  bool scanning = false;
  MobileScannerController qrController = MobileScannerController();

  void _onDetect(BarcodeCapture capture) {
    final Barcode? barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode != null && barcode.rawValue != null) {
      qrController.stop(); // Pause scanner
      _handleReceivedCard(barcode.rawValue);
    }
  }

  Future<void> _startNfcRead() async {
    setState(() {
      scanning = true;
      nfcStatus = "Waiting for NFC card...";
    });
    try {
      NFCAvailability avail = await FlutterNfcKit.nfcAvailability;
      if (avail != NFCAvailability.available) {
        setState(() {
          nfcStatus = "NFC not available!";
          scanning = false;
        });
        return;
      }
      var tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 15));
      if (tag.ndefAvailable == true) {
        var ndefRecords = await FlutterNfcKit.readNDEFRecords();
        if (ndefRecords.isNotEmpty && ndefRecords.first.payload != null && (ndefRecords.first.payload?.isNotEmpty ?? false)) {
          final payload = ndefRecords.first.payload!;
          // Skip the status byte (1 byte) and language code (2 bytes for 'en')
          if (payload.length < 3) {
            setState(() {
              nfcStatus = "Invalid NDEF text record.";
            });
            return;
          }
          final data = utf8.decode(payload.sublist(3)); // Skip status byte (1) + language code (2)
          _handleReceivedCard(data);
        } else {
          setState(() {
            nfcStatus = "No card data found on NFC tag.";
          });
        }
      } else {
        setState(() {
          nfcStatus = "Tag is not NDEF formatted.";
        });
      }
      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() {
        nfcStatus = "NFC error: $e";
      });
      await FlutterNfcKit.finish();
    }
    setState(() {
      scanning = false;
    });
  }

  void _handleReceivedCard(String? data) {
    setState(() {
      scanning = false;
      nfcStatus = null;
    });
    if (data == null || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No card data found!")));
      return;
    }
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      setState(() {
        receivedCard = map;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to parse card: $e")));
    }
  }

  void _saveCard() async {
    if (receivedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No card data to save!")));
      return;
    }
    try {
      await CardDbService().addCard(
        receivedCard!['name'] ?? '',
        receivedCard!['masked_card_number'] ?? '',
        receivedCard!['expiry'] ?? '',
        nfcId: receivedCard!['nfcId']?.isNotEmpty ?? false ? receivedCard!['nfcId'] : null,
        paymentLink: receivedCard!['paymentLink']?.isNotEmpty ?? false ? receivedCard!['paymentLink'] : null,
        balance: double.tryParse(receivedCard!['balance'].toString()) ?? 0,
      );
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Card saved successfully!")));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save card: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D21),
      appBar: AppBar(
        title: const Text("Receive Card"),
        backgroundColor: const Color(0xFF1A1D21),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.amber,
              padding: const EdgeInsets.all(8),
              child: const Text(
                "For DEMO/EDUCATION only! Never share/receive real cards.",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (receivedCard == null) ...[
              const Text(
                "Scan QR code or tap NFC card",
                style: TextStyle(color: Colors.greenAccent, fontSize: 18),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 250,
                height: 250,
                child: MobileScanner(
                  controller: qrController,
                  onDetect: _onDetect,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.nfc),
                label: scanning
                    ? const Text("Scanning...")
                    : const Text("Receive via NFC"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: scanning ? null : _startNfcRead,
              ),
              if (nfcStatus != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    nfcStatus!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
            if (receivedCard != null) ...[
              const SizedBox(height: 24),
              const Text("Received Card Data:",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
              Card(
                color: const Color(0xFF23272A),
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: receivedCard!.entries
                        .map((e) => Text(
                              "${e.key}: ${e.value}",
                              style: const TextStyle(
                                  color: Colors.greenAccent, fontSize: 16),
                            ))
                        .toList(),
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Card"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: _saveCard,
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    receivedCard = null;
                    qrController.start();
                  });
                },
                child: const Text("Scan Again", style: TextStyle(color: Colors.greenAccent)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    qrController.dispose();
    super.dispose();
  }
}