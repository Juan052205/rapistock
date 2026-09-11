import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/play_billing_service.dart';
import '../data/play_integrity_service.dart';
import '../data/seed.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/ad_gate.dart';
import 'clientes.dart';
import 'conteo.dart';
import 'escritorio.dart';

class AjustesPantalla extends StatefulWidget {
  const AjustesPantalla({super.key});

  @override
  State<AjustesPantalla> createState() => _AjustesPantallaState();
}

class _AjustesPantallaState extends State<AjustesPantalla> {
  late final TextEditingController nombre;
  late final TextEditingController nit;
  late final TextEditingController direccion;
  String estadoSeguridad = 'Verificando integridad...';
  bool primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (primed) return;
    final n = context.read<Store>().negocio;
    final raw = n.nombre.trim();
    nombre = TextEditingController(text: (raw.isEmpty || raw == 'Mi negocio') ? '' : raw);
    nit = TextEditingController(text: n.nit);
    direccion = TextEditingController(text: n.direccion);
    primed = true;
    _validarSeguridad();
  }

  Future<void> _validarSeguridad() async {
    final ok = await PlayIntegrityService.verificarIntegridadDispositivo();
    if (!mounted) return;
    setState(() {
      estadoSeguridad = ok
          ? 'El celular pasó la revisión de Google'
          : 'No se pudo revisar el celular';
    });
  }

  @override
  void dispose() {
    if (primed) {
      nombre.dispose();
      nit.dispose();
      direccion.dispose();
    }
    super.dispose();
  }

  void _aviso(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? R.ok : R.danger,
      ),
    );
  }

  Future<void> _abrirConteo() async {
    final store = context.read<Store>();
    final seguir = await anuncioSiGratis(context, esPro: store.negocio.esPro);
    if (!seguir || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConteoPantalla()));
  }

  Future<void> _cargarEjemplo() async {
    final store = context.read<Store>();
    final tieneDatos = store.productos.isNotEmpty || store.movimientos.isNotEmpty;
    final esSuya = tieneDatos && !store.negocio.esDemo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esSuya ? 'Se van a borrar TUS datos' : 'Cargar tienda de ejemplo'),
        content: Text(
          esSuya
              ? 'Tienes ${store.productos.length} productos y ${store.movimientos.length} movimientos de TU negocio. Si cargas el ejemplo, eso se borra y no se puede deshacer.\n\n¿Seguro?'
              : 'Se llena la app con productos de prueba (arroz, aceite, leche…). Si más adelante no los quieres, toca “Quitar tienda de ejemplo”.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: esSuya ? R.danger : R.forest),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(esSuya ? 'Sí, borrar los míos' : 'Cargar ejemplo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final seguir = await anuncioSiGratis(context, esPro: store.negocio.esPro);
    if (!seguir || !mounted) return;

    await store.restaurarDemo();
    nombre.text = demoNombre;
    nit.text = demoNit;
    direccion.text = demoDireccion;
    _aviso('Tienda de ejemplo cargada');
  }

  Future<void> _quitarEjemplo() async {
    final store = context.read<Store>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar tienda de ejemplo'),
        content: const Text('La bodega queda vacía, como si acabaras de instalar la app. Tus datos de Pro se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.forest),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar ejemplo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await store.vaciarBodega();
    nombre.clear();
    nit.clear();
    direccion.clear();
    _aviso('Ejemplo quitado. Bodega vacía');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final pro = store.negocio.esPro;
    const plan = [
      ['Productos en bodega', '$limiteSkuGratis', 'Ilimitados'],
      ['Clientes guardados', '$limiteClientesGratis', 'Ilimitados'],
      ['Descargas Excel / mes', '$limiteReportesGratis + aviso', 'Ilimitadas'],
      ['Elegir fechas en el Excel', 'No', 'Sí'],
      ['Análisis de mercado (ABC)', 'No', 'Sí'],
      ['Usar en el computador (QR)', 'No', 'Hasta $maxComputadores PCs'],
      ['Vender aunque la app diga 0', 'No', 'Tú eliges'],
      ['Sin avisos al guardar', 'No', 'Sí'],
      ['El historial no se borra', 'Sí', 'Sí'],
      ['Contar lo del estante', 'Sí', 'Sí'],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes y versión Pro')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TU NEGOCIO', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: R.muted)),
                  TextField(
                    controller: nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del negocio',
                      hintText: 'Ej. Tienda Don Pedro',
                    ),
                  ),
                  TextField(
                    controller: nit,
                    decoration: const InputDecoration(labelText: 'NIT (opcional)', hintText: '900.000.000-0'),
                  ),
                  TextField(
                    controller: direccion,
                    decoration: const InputDecoration(labelText: 'Dirección (opcional)', hintText: 'Barrio, calle...'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: R.forest),
                      onPressed: () async {
                        final ok = await store.guardarNegocio(store.negocio.copyWith(
                          nombre: nombre.text.trim(),
                          nit: nit.text.trim(),
                          direccion: direccion.text.trim(),
                          esDemo: false,
                        ));
                        if (!mounted) return;
                        _aviso(ok ? 'Datos del negocio guardados' : 'No pude guardar. Intenta de nuevo.', ok: ok);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: R.forest),
              title: const Text('Clientes'),
              subtitle: Text(
                store.clientes.isEmpty
                    ? 'Guarda a Doña Rosa, el restaurante… y véndeles con un toque'
                    : '${store.clientes.length} guardados · toca para ver o agregar',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientesPantalla()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(pro ? 'Rapistock Pro (sin límites)' : 'Rapistock gratuito', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  subtitle: Text(
                    pro
                        ? 'Productos ilimitados, Excel con fechas y cero avisos.'
                        : 'Tope: $limiteSkuGratis productos, $limiteClientesGratis clientes y $limiteReportesGratis descargas al mes.',
                  ),
                  trailing: Chip(
                    label: Text(pro ? 'Pro' : 'Gratis'),
                    backgroundColor: pro ? R.pro : const Color(0xFFEBE6D9),
                    labelStyle: TextStyle(color: pro ? R.proFg : R.muted, fontWeight: FontWeight.w700),
                  ),
                ),
                Table(
                  columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                  children: [
                    const TableRow(children: [
                      Padding(padding: EdgeInsets.all(8), child: Text('Qué incluye', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Gratis', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: R.pro))),
                    ]),
                    for (final r in plan)
                      TableRow(children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(r[0], style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(r[1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: R.muted))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(r[2], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: R.forest))),
                      ]),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: pro
                        ? OutlinedButton(
                      onPressed: () async {
                        await store.desactivarPro();
                        if (mounted) _aviso('Cuenta gratis restaurada (para probar)');
                      },
                      child: const Text('Volver a la cuenta gratis (para probar)'),
                    )
                        : FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: R.pro, foregroundColor: R.proFg, minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        final ok = await PlayBillingService.comprarLicenciaPro(context);
                        if (ok) {
                          await store.activarPro();
                          if (mounted) _aviso('Listo: ya tienes Rapistock Pro');
                        }
                      },
                      child: const Text('Pasarme a Rapistock Pro'),
                    ),
                  ),
                ),
                if (pro)
                  SwitchListTile(
                    title: const Text('Vender aunque la app diga 0'),
                    subtitle: const Text(
                      'A veces el cliente te pide algo y en la app aparece en ceros, pero tú sí lo vendes (el estante no está al día). Si lo enciendes, la venta se registra igual y queda marcada para que después cuentes el estante y corrijas. Así no dejas ir al cliente.',
                    ),
                    isThreeLine: true,
                    value: store.negocio.permitirStockNegativo,
                    activeThumbColor: R.forest,
                    onChanged: (v) => store.guardarNegocio(store.negocio.copyWith(permitirStockNegativo: v)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.checklist, color: R.forest),
                  title: const Text('Contar lo del estante'),
                  subtitle: const Text('Caminas el pasillo, escribes lo que ves y la app corrige'),
                  onTap: _abrirConteo,
                ),
                ListTile(
                  leading: const Icon(Icons.computer, color: R.forest),
                  title: const Text('Usar en el computador'),
                  subtitle: const Text('Pro: ves la bodega en el PC con un QR. Hasta 2 computadores.'),
                  trailing: pro
                      ? null
                      : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: R.pro, borderRadius: BorderRadius.circular(99)),
                    child: const Text('Pro', style: TextStyle(color: R.proFg, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EscritorioPantalla()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.security, color: R.forest),
                  title: const Text('Seguridad del celular'),
                  subtitle: Text(estadoSeguridad),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Acerca de Rapistock'),
                  subtitle: Text('Versión 1.2.0 · Hecho para comercios en Colombia'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tienda de ejemplo', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'Es solo para mirar cómo se ve la app llena. No se carga sola. Si ya tienes tus productos, la app te va a avisar antes de borrar nada.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _cargarEjemplo,
                    icon: const Icon(Icons.storefront, color: R.forest),
                    label: const Text('Cargar tienda de ejemplo'),
                  ),
                  if (store.negocio.esDemo) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _quitarEjemplo,
                      icon: const Icon(Icons.delete_outline, color: R.danger),
                      label: const Text('Quitar tienda de ejemplo', style: TextStyle(color: R.danger)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}