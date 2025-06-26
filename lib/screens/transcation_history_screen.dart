import 'package:flutter/material.dart';
import 'package:nfc_phone_pay/services/card_dv_services.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: CardDbService().getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final history = snapshot.data!;
          if (history.isEmpty) return const Center(child: Text('No transactions yet.'));
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, idx) {
              final tx = history[idx];
              return ListTile(
                title: Text('Card ID: ${tx['cardId']}'),
                subtitle: Text('Link: ${tx['paymentLink']}\nAt: ${tx['timestamp']}'),
              );
            },
          );
        },
      ),
    );
  }
}