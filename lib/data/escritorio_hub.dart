/// El servidor WiFi local (paquete shelf) se retiró.
/// Rapistock en el computador ahora usa Firebase + la página de Netlify.
///
/// Este archivo queda vacío a propósito para que el proyecto compile
/// si todavía está en lib/data/. Puedes BORRARLO sin problema:
/// nadie más lo importa.
class EscritorioHub {
  static bool get activo => false;
  static String? get url => null;
  static String token = '';
  static String? ip;
  static const int puerto = 4780;
}