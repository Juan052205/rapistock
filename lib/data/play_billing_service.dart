import 'package:flutter/material.dart';

class PlayBillingService {
  /// Simula Google Play Billing. En producción reemplaza esto por
  /// `in_app_purchase` / Play Billing Library (suscripción mensual).
  static Future<bool> comprarLicenciaPro(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Google Play Billing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Conectando con la tienda para procesar suscripción Pro...'),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.of(context).pop();
    return true;
  }
}