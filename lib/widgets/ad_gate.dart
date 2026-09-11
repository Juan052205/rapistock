import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


/// IDs reales de Rapistock en AdMob.
/// En debug (Run de Android Studio) se usan anuncios de PRUEBA de Google
/// para no arriesgar la cuenta. En el .aab de Play salen los de verdad.
class AdMobRapistock {
  static const appId = 'ca-app-pub-7567540983279751~4779047282';
  static const interstitialProd = 'ca-app-pub-7567540983279751/6559761764';
  static const rewardedProd = 'ca-app-pub-7567540983279751/3274393921';

  static const interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const rewardedTest = 'ca-app-pub-3940256099942544/5224354917';

  static String get interstitialId => kDebugMode ? interstitialTest : interstitialProd;
  static String get rewardedId => kDebugMode ? rewardedTest : rewardedProd;
}

/// Si es Pro, sigue de una. Si es gratis, muestra un intersticial de AdMob.
/// Devuelve false si eligió “Prefiero Pro”.
/// Si el anuncio no carga, deja pasar.
Future<bool> anuncioSiGratis(BuildContext context, {required bool esPro}) async {
  if (esPro) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _AdCargandoDialog(),
  );
  return ok == true;
}

class _AdCargandoDialog extends StatefulWidget {
  const _AdCargandoDialog();

  @override
  State<_AdCargandoDialog> createState() => _AdCargandoDialogState();
}

class _AdCargandoDialogState extends State<_AdCargandoDialog> {
  InterstitialAd? _ad;
  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _salir(bool seguir) async {
    if (_cerrado) return;
    _cerrado = true;
    _ad?.dispose();
    _ad = null;
    if (mounted) Navigator.of(context).pop(seguir);
  }

  Future<void> _cargar() async {
    try {
      final res = await InternetAddress.lookup('google.com');
      if (res.isEmpty || res.first.rawAddress.isEmpty) {
        await _salir(true);
        return;
      }
    } on SocketException {
      await _salir(true);
      return;
    }

    if (_cerrado || !mounted) return;

    await InterstitialAd.load(
      adUnitId: AdMobRapistock.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (_cerrado || !mounted) {
            ad.dispose();
            return;
          }
          _ad = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _salir(true);
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _salir(true);
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdMob interstitial: $error');
          _salir(true);
        },
      ),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Un aviso corto'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('En la versión gratis hay un aviso. Pro los quita todos.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _salir(false),
          child: const Text('Prefiero Pro'),
        ),
      ],
    );
  }
}