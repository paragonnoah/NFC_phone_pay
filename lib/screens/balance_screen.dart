import 'package:flutter/material.dart';
import 'package:nfc_phone_pay/services/card_dv_services.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Balances')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: CardDbService().getCards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final cards = snapshot.data!;
          if (cards.isEmpty)
            return const Center(child: Text('No cards found.'));
          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, idx) {
              final card = cards[idx];
              return ListTile(
                title: Text(card['name'] ?? ''),
                subtitle: Text('Balance: ${card['balance'] ?? 0}'),
                trailing: Text(card['masked_card_number'] ?? '',
                    style: const TextStyle(fontFamily: 'FiraMono')),
              );
            },
          );
        },
      ),
    );
  }
}
