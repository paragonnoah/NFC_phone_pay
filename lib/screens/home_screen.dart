import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_phone_pay/services/card_dv_services.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> cards = [];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final data = await CardDbService().getCards();
    setState(() {
      cards = data;
    });
  }

  Future<void> _addCard() async {
    final nameController = TextEditingController();
    final tokenController = TextEditingController();
    final paymentLinkController = TextEditingController();

    String? nfcId;

    bool isAssigningNFC = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF23272A),
            title: const Text('Add Card', style: TextStyle(color: Colors.greenAccent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.greenAccent),
                  decoration: const InputDecoration(labelText: 'Card Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenController,
                  style: const TextStyle(color: Colors.greenAccent),
                  decoration: const InputDecoration(labelText: 'Token (any unique value)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: paymentLinkController,
                  style: const TextStyle(color: Colors.greenAccent),
                  decoration: const InputDecoration(labelText: 'Payment Link (optional)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.nfc),
                      label: Text(nfcId == null ? 'Assign NFC Tag' : 'Reassign NFC Tag'),
                      onPressed: isAssigningNFC
                          ? null
                          : () async {
                              setDialogState(() => isAssigningNFC = true);
                              try {
                                var avail = await FlutterNfcKit.nfcAvailability;
                                if (avail != NFCAvailability.available) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NFC not available')));
                                  setDialogState(() => isAssigningNFC = false);
                                  return;
                                }
                                var tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 10));
                                nfcId = tag.id;
                                setDialogState(() => isAssigningNFC = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('NFC tag assigned! ID: $nfcId')));
                                await FlutterNfcKit.finish();
                              } catch (e) {
                                setDialogState(() => isAssigningNFC = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('NFC Error: $e')));
                                await FlutterNfcKit.finish();
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    if (nfcId != null)
                      Flexible(child: Text('Tag: $nfcId', style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && tokenController.text.isNotEmpty) {
                    await CardDbService().addCard(
                      nameController.text,
                      tokenController.text,
                      nfcId: nfcId,
                      paymentLink: paymentLinkController.text.isNotEmpty ? paymentLinkController.text : null,
                    );
                    Navigator.of(context).pop();
                    _loadCards();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Token required')));
                  }
                },
                child: const Text('Add', style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeCard(int id) async {
    await CardDbService().deleteCard(id);
    _loadCards();
  }

  void _showPaymentLink(String cardName, String? link) {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment link assigned to this card!')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF23272A),
        title: Row(
          children: [
            const Icon(Icons.link, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text('Payment Link', style: TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cardName, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Link'),
              onPressed: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment link copied!')),
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Open Link'),
              onPressed: () async {
                final url = Uri.parse(link);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch payment link!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tapToPay() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC not available on this device!')),
        );
        return;
      }
      var tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 10));
      await FlutterNfcKit.finish();

      if (!mounted) return;

      // Look up card by tag.id
      final card = cards.firstWhere(
        (c) => c['nfcId'] == tag.id,
        orElse: () => {},
      );

      if (card.isNotEmpty && card['paymentLink'] != null && (card['paymentLink'] as String).isNotEmpty) {
        final url = Uri.parse(card['paymentLink']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch payment link!')),
          );
        }
      } else {
        // Show info if no payment link is set for this tag
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF23272A),
            title: const Text('NFC Tag Detected!', style: TextStyle(color: Colors.greenAccent)),
            content: Text('Type: ${tag.type}\nID: ${tag.id}\nStandard: ${tag.standard}',
                style: const TextStyle(color: Colors.greenAccent)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      await FlutterNfcKit.finish();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Phone Pay'),
      ),
      body: Column(
        children: [
          Expanded(
            child: cards.isEmpty
                ? const Center(child: Text('No cards yet.'))
                : ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Card(
                        color: const Color(0xFF23272A),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ListTile(
                          leading: const Icon(Icons.credit_card, color: Colors.greenAccent),
                          title: Text(card['name'] ?? 'Card ${index + 1}', style: const TextStyle(color: Colors.greenAccent)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card['token'] ?? '', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                              if (card['nfcId'] != null && (card['nfcId'] as String).isNotEmpty)
                                Text('NFC: ${card['nfcId']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                              if (card['paymentLink'] != null && (card['paymentLink'] as String).isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showPaymentLink(card['name'], card['paymentLink']),
                                  child: Text(
                                    '🔗 Payment Link',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.greenAccent),
                                tooltip: 'Show Payment Link',
                                onPressed: () => _showPaymentLink(card['name'], card['paymentLink']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _removeCard(card['id'] as int),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.nfc),
                label: const Text('Tap to Pay'),
                onPressed: _tapToPay,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(Icons.add),
        tooltip: 'Add Card',
      ),
    );
  }
}