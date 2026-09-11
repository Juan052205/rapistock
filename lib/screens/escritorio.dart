import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../data/nube.dart';
import '../data/nube_config.dart';
import '../data/play_billing_service.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';

class EscritorioPantalla extends StatefulWidget {
  const EscritorioPantalla({super.key});

  @override
  State<EscritorioPantalla> createState() => _EscritorioPantallaState();
}

class _EscritorioPantallaState extends State<EscritorioPantalla> {
  bool cargando = false;
  String? error;

  Future<void> _preparar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final store = context.read<Store>();
      await store.activarEscritorioNube();
    } catch (e) {
      error = 'No pude subir la bodega. Revisa que el celular tenga internet.';
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  String _hace(int ms) {
    if (ms <= 0) return 'conectado';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
  }

  Future<void> _cerrarTodos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar los computadores'),
        content: const Text(
          'Los PCs que tengan el link abierto se van a desconectar (como cuando cierras WhatsApp Web). '
              'El celular genera un código nuevo. Para volver a usar el computador hay que escanear el QR otra vez.\n\n'
              'La bodega del celular no se borra.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar computadores'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => cargando = true);
    try {
      await context.read<Store>().cerrarComputadores();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Computadores cerrados. Escanea el QR de nuevo para entrar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final pro = store.negocio.esPro;
    final codigo = store.negocio.codigoNube;
    final url = (Nube.lista && codigo.isNotEmpty) ? Nube.enlacePc(codigo) : null;
    final pcs = store.dispositivosNube;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapistock en el computador')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottom),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B4D3E), Color(0xFF2E7A62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRO', style: TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w800, letterSpacing: 2)),
                  SizedBox(height: 8),
                  Text('Como WhatsApp: el computador se queda', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    'Escaneas una vez. El link es siempre el mismo. El celular puede irse, bloquearse o cambiar de red. El computador sigue vendiendo porque los datos viven en internet, no en el WiFi. Hasta 2 computadores a la vez.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!Nube.lista) ...[
              const Text('Falta un paso de una sola vez', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Hay que crear la “nube” gratis (Firebase) y subir la página del computador.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 8),
              Text('Ahora mismo dice:\nDB: $kNubeDb\nWeb: $kNubeWeb', style: const TextStyle(fontSize: 12, color: R.muted)),
            ] else if (!pro) ...[
              const _Paso(n: '1', t: 'Activas Rapistock Pro en este celular.'),
              const _Paso(n: '2', t: 'Tocas “Mostrar código”. Sale un QR y un link https.'),
              const _Paso(n: '3', t: 'En el computador abres ese link (queda de marcador). Ya no hace falta el mismo WiFi.'),
              const _Paso(n: '4', t: 'Cada negocio tiene su propia clave. Nadie más ve tus datos.'),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: R.pro, foregroundColor: R.proFg, minimumSize: const Size.fromHeight(52)),
                onPressed: () async {
                  final ok = await PlayBillingService.comprarLicenciaPro(context);
                  if (ok) {
                    await store.activarPro();
                    if (mounted) setState(() {});
                  }
                },
                child: const Text('Quiero esto · pasarme a Pro'),
              ),
            ] else ...[
              if (url == null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: R.forest, minimumSize: const Size.fromHeight(52)),
                  onPressed: cargando ? null : _preparar,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(cargando ? 'Subiendo bodega…' : 'Mostrar código para el computador'),
                )
              else ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(data: url, size: 220, backgroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    codigo,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4, color: R.forest),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(url, textAlign: TextAlign.center, style: const TextStyle(color: R.muted)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: R.forest, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Share.share(
                    'Rapistock en el computador (ábrelo, no hace falta el mismo WiFi):\n$url',
                    subject: 'Rapistock',
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Enviar link por WhatsApp'),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar link'),
                  ),
                ),
                const Text(
                  'Guarda este link en el computador (marcador). El celular no tiene que quedarse abierto.',
                  style: TextStyle(color: R.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _preparar,
                  child: const Text('Volver a subir la bodega ahora'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Computadores conectados · ${pcs.length} de $maxComputadores',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Si alguien abre el mismo link en un tercer PC, no entra. Quita uno de la lista o cierra todos.',
                  style: TextStyle(fontSize: 12, color: R.muted, height: 1.35),
                ),
                const SizedBox(height: 8),
                if (pcs.isEmpty)
                  const Text('Todavía no hay ningún computador. Abre el link en el PC.', style: TextStyle(color: R.muted))
                else
                  ...pcs.map(
                        (d) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.desktop_windows_outlined, color: R.forest),
                        title: Text(d.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(_hace(d.lastSeen)),
                        trailing: IconButton(
                          tooltip: 'Quitar este computador',
                          icon: const Icon(Icons.logout, color: R.danger),
                          onPressed: () => store.quitarDispositivo(d.id),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: cargando ? null : _cerrarTodos,
                  icon: const Icon(Icons.link_off, color: R.danger),
                  label: const Text('Cerrar todos los computadores', style: TextStyle(color: R.danger)),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: R.danger)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final String n;
  final String t;
  const _Paso({required this.n, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: R.forest,
            child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}