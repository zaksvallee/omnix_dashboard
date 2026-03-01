import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class LedgerPage extends StatefulWidget {
  final String clientId;

  const LedgerPage({
    super.key,
    required this.clientId,
  });

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  List<Map<String, dynamic>> _rows = [];
  String? _verificationResult;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    final client = Supabase.instance.client;

    final data = await client
        .from('client_evidence_ledger')
        .select()
        .eq('client_id', widget.clientId)
        .order('created_at', ascending: true);

    setState(() {
      _rows = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _verifyChain() async {
    String? previousHash;

    for (final row in _rows) {
      final canonicalJson = row['canonical_json'];
      final storedHash = row['hash'];

      final combined = previousHash == null
          ? canonicalJson
          : canonicalJson + previousHash;

      final computedHash = sha256
          .convert(Uint8List.fromList(utf8.encode(combined)))
          .toString();

      if (computedHash != storedHash) {
        setState(() {
          _verificationResult = "❌ Chain integrity FAILED";
        });
        return;
      }

      previousHash = storedHash;
    }

    setState(() {
      _verificationResult = "✅ Chain integrity VERIFIED";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ledger — ${widget.clientId}",
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyChain,
              child: const Text("Verify Chain"),
            ),
            const SizedBox(height: 16),
            if (_verificationResult != null)
              Text(_verificationResult!),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(row['dispatch_id']),
                      subtitle: Text(row['hash']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
