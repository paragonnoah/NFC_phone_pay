import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:credit_card_validator/credit_card_validator.dart';
import 'package:nfc_phone_pay/services/card_dv_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> cards = [];
  List<Map<String, dynamic>> transactions = [];
  final validator = CreditCardValidator();

  @override
  void initState() {
    super.initState();
    _loadCards();
    _loadTransactions();
  }

  Future<void> _loadCards() async {
    final data = await CardDbService().getCards();
    // Debug print for troubleshooting
    print("Loaded cards: $data");
    setState(() => cards = data);
  }

  Future<void> _loadTransactions() async {
    final history = await CardDbService().getTransactions();
    setState(() => transactions = history);
  }

  Future<String?> _promptForCvv(BuildContext context) async {
    final controller = TextEditingController();
    String? cvv;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter CVV'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'CVV'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cvv = controller.text;
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return cvv;
  }

  bool validateCardInput(BuildContext context, String cardNumber, String expiry, String cvv) {
    // Card number validation (Luhn check)
    final ccNumResult = validator.validateCCNum(cardNumber.trim());
    if (!ccNumResult.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid card number!')),
      );
      return false;
    }

    // Expiry validation: MM/YY, not in the past
    final regExp = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$');
    if (!regExp.hasMatch(expiry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid expiry date! Format must be MM/YY')),
      );
      return false;
    }
    final parts = expiry.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse('20${parts[1]}');
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card is expired!')),
      );
      return false;
    }

    // CVV validation: 3 or 4 digits
    if (cvv.isEmpty || (cvv.length != 3 && cvv.length != 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CVV must be 3 or 4 digits!')),
      );
      return false;
    }

    return true;
  }

  Future<void> _addCard() async {
    final nameController = TextEditingController();
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final paymentLinkController = TextEditingController();
    final balanceController = TextEditingController();

    String? nfcId;
    bool isAssigningNFC = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF23272A),
            title: const Text('Add Card', style: TextStyle(color: Colors.greenAccent)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Cardholder Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cardNumberController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Card Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiryController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cvvController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'CVV'),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: paymentLinkController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Payment Link (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balanceController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Balance'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  final cardNumber = cardNumberController.text.trim();
                  final expiry = expiryController.text.trim();
                  final cvv = cvvController.text.trim();
                  if (!validateCardInput(context, cardNumber, expiry, cvv)) return;

                  if (nameController.text.isNotEmpty &&
                      cardNumber.isNotEmpty &&
                      expiry.isNotEmpty &&
                      cvv.isNotEmpty) {
                    try {
                      await CardDbService().addCard(
                        nameController.text,
                        cardNumber,
                        expiry,
                        // Only save CVV temporarily for the session, do not store long-term!
                        nfcId: nfcId,
                        paymentLink: paymentLinkController.text.isNotEmpty ? paymentLinkController.text : null,
                        balance: double.tryParse(balanceController.text) ?? 0,
                      );
                      Navigator.of(context).pop();
                      _loadCards();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Number, Expiry, and CVV required')));
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

  Future<void> _editCard(Map<String, dynamic> card) async {
    final nameController = TextEditingController(text: card['name']);
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController(text: card['expiry'] ?? '');
    final cvvController = TextEditingController();
    final paymentLinkController = TextEditingController(text: card['paymentLink'] ?? '');
    final balanceController = TextEditingController(text: (card['balance'] ?? 0).toString());

    String? nfcId = card['nfcId'];
    bool isAssigningNFC = false;

    String? fullCardNumber;
    if (card['card_number'] != null) {
      fullCardNumber = await CardDbService().decryptCardNumber(card['card_number'] as String);
      cardNumberController.text = fullCardNumber;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF23272A),
            title: const Text('Edit Card', style: TextStyle(color: Colors.greenAccent)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Cardholder Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cardNumberController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Card Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiryController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cvvController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'CVV'),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: paymentLinkController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Payment Link (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balanceController,
                    style: const TextStyle(color: Colors.greenAccent),
                    decoration: const InputDecoration(labelText: 'Balance'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  final cardNumber = cardNumberController.text.trim();
                  final expiry = expiryController.text.trim();
                  final cvv = cvvController.text.trim();
                  if (!validateCardInput(context, cardNumber, expiry, cvv)) return;

                  if (nameController.text.isNotEmpty &&
                      cardNumber.isNotEmpty &&
                      expiry.isNotEmpty &&
                      cvv.isNotEmpty) {
                    try {
                      await CardDbService().updateCard(
                        card['id'],
                        name: nameController.text,
                        cardNumber: cardNumber,
                        expiry: expiry,
                        // Only use cvv for this session
                        nfcId: nfcId,
                        paymentLink: paymentLinkController.text.isNotEmpty ? paymentLinkController.text : null,
                        balance: double.tryParse(balanceController.text) ?? 0,
                      );
                      Navigator.of(context).pop();
                      _loadCards();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Number, Expiry, and CVV required')));
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.greenAccent)),
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
    _loadTransactions();
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

  void _showBalances() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF23272A),
        title: const Text('Card Balances', style: TextStyle(color: Colors.greenAccent)),
        content: SizedBox(
          width: double.maxFinite,
          child: cards.isEmpty
              ? const Text('No cards found.', style: TextStyle(color: Colors.greenAccent))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: cards.length,
                  itemBuilder: (context, idx) {
                    final card = cards[idx];
                    return ListTile(
                      title: Text(card['name'] ?? '', style: const TextStyle(color: Colors.greenAccent)),
                      subtitle: Text('Balance: ${card['balance'] ?? 0}', style: const TextStyle(color: Colors.greenAccent)),
                      trailing: Text(card['masked_card_number'] ?? '', style: const TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono')),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.greenAccent)),
          )
        ],
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

      final card = cards.firstWhere(
        (c) => c['nfcId'] == tag.id,
        orElse: () => {},
      );

      if (card.isNotEmpty && card['paymentLink'] != null && (card['paymentLink'] as String).isNotEmpty) {
        final amount = await _promptForAmount();
        if (amount == null || amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount!')));
          return;
        }
        final cvv = await _promptForCvv(context);
        if (cvv == null || cvv.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CVV is required.')));
          return;
        }
        final cardBalance = card['balance'] ?? 0.0;
        if (cardBalance < amount) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance!')));
          return;
        }
        final url = Uri.parse(card['paymentLink']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          await CardDbService().logTransaction(card['id'] as int, card['paymentLink'], amount);
          await CardDbService().deductBalance(card['id'] as int, amount);
          _loadCards();
          _loadTransactions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch payment link!')),
          );
        }
      } else {
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

  Future<double?> _promptForAmount() async {
    final controller = TextEditingController();
    double? amount;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23272A),
        title: const Text('Enter Amount to Pay', style: TextStyle(color: Colors.greenAccent)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
          style: const TextStyle(color: Colors.greenAccent),
        ),
        actions: [
          TextButton(
            onPressed: () {
              amount = double.tryParse(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
    return amount;
  }

  void _showTransactions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF23272A),
        title: const Text('Transaction History', style: TextStyle(color: Colors.greenAccent)),
        content: SizedBox(
          width: double.maxFinite,
          child: transactions.isEmpty
              ? const Text('No transactions yet.', style: TextStyle(color: Colors.greenAccent))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, idx) {
                    final tx = transactions[idx];
                    return ListTile(
                      title: Text('Card ID: ${tx['cardId']}', style: const TextStyle(color: Colors.greenAccent)),
                      subtitle: Text(
                        'Amount: ${tx['amount']}\n${tx['paymentLink']}\n${tx['timestamp']}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.greenAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Phone Pay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
            tooltip: 'Check Balances',
            onPressed: _showBalances,
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.greenAccent),
            tooltip: 'Transaction History',
            onPressed: _showTransactions,
          ),
        ],
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
                              Text(card['masked_card_number'] ?? '', style: const TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono', fontSize: 12)),
                              Text('Expiry: ${card['expiry'] ?? ''}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                              Text('Balance: ${card['balance'] ?? 0}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
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
                                icon: const Icon(Icons.edit, color: Colors.lightBlueAccent),
                                tooltip: 'Edit Card',
                                onPressed: () => _editCard(card),
                              ),
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.greenAccent),
                                tooltip: 'Show Payment Link',
                                onPressed: () => _showPaymentLink(card['name'], card['paymentLink']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _removeCard(card['id'] as int),
                              ),
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