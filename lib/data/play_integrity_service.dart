import 'package:flutter/foundation.dart';

class PlayIntegrityService {
  static Future<bool> verificarIntegridadDispositivo() async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      return true;
    } catch (e) {
      debugPrint('Error de integridad: $e');
      return false;
    }
  }
}