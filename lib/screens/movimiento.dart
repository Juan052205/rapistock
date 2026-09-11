import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/format.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/stock_meter.dart';
import 'clientes.dart';

class MovimientoPantalla extends StatefulWidget {
  const MovimientoPantalla({super.key});

  @override
  State<MovimientoPantalla> createState() => _MovimientoPantallaState();
}

class _MovimientoPantallaState extends State<MovimientoPantalla> {
  String q = '';
  late final TextEditingController referencia;
  late final TextEditingController proveedor;
  late final TextEditingController qtyDraft;

  @override
  void initState() {
    super.initState();
    referencia = TextEditingController();
    proveedor = TextEditingController();
    qtyDraft = TextEditingController();
  }

  @override
  void dispose() {
    referencia.dispose();
    proveedor.dispose();
    qtyDraft.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editarCantidad(int productoId, int cant) async {
    final store = context.read<Store>();
    qtyDraft.text = cant > 0 ? '$cant' : '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cuántas unidades?'),
        content: TextField(
          controller: qtyDraft,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ej. 24'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.forest),
            onPressed: () {
              final nQty = int.tryParse(qtyDraft.text) ?? 0;
              final r = store.setCantidad(productoId, nQty);
              Navigator.pop(ctx);
              if (!r.ok && r.reason == 'stock') {
                _toast('No hay tantas unidades en bodega');
              }
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _elegirCliente() async {
    final r = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => const ClientesPantalla(elegir: true)),
    );
    if (!mounted || r == null) return;
    context.read<Store>().setClienteVenta(r is Cliente ? r : null);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final n = q.trim().toLowerCase();
    final visibles = store.productos.where((p) {
      if (n.isEmpty) return true;
      return p.nombre.toLowerCase().contains(n) ||
          p.codigoRef.toLowerCase().contains(n) ||
          p.categoria.toLowerCase().contains(n);
    }).toList();
    final motivos = store.tipoCarrito == 'ENTRADA' ? motivosEntrada : motivosSalida;
    final items = store.carrito.fold<int>(0, (s, c) => s + c.cantidad);
    final valor = store.valorCarrito();
    final motivoActual = motivos.contains(store.motivo) ? store.motivo : motivos.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Entradas y salidas')),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: R.bg, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TipoBtn(
                                  label: 'Entra',
                                  hint: 'Llegó mercancía',
                                  active: store.tipoCarrito == 'ENTRADA',
                                  color: R.ok,
                                  onTap: () => store.setTipoCarrito('ENTRADA'),
                                ),
                              ),
                              Expanded(
                                child: _TipoBtn(
                                  label: 'Sale',
                                  hint: 'Se vendió o salió',
                                  active: store.tipoCarrito == 'SALIDA',
                                  color: R.ink,
                                  onTap: () => store.setTipoCarrito('SALIDA'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(store.tipoCarrito),
                          initialValue: motivoActual,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Motivo',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: motivos
                              .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) store.setMotivo(v);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: referencia,
                          decoration: InputDecoration(
                            labelText: store.tipoCarrito == 'ENTRADA' ? 'N° de factura (opcional)' : 'N° de venta (opcional)',
                            hintText: store.tipoCarrito == 'ENTRADA' ? 'FC-1842' : 'V-2201',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: store.setReferencia,
                        ),
                        if (store.tipoCarrito == 'ENTRADA') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: proveedor,
                            decoration: const InputDecoration(
                              labelText: '¿De quién se compró? (opcional)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: store.setProveedorDoc,
                          ),
                        ],
                        if (store.tipoCarrito == 'SALIDA') ...[
                          const SizedBox(height: 8),
                          Material(
                            color: R.bg,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                store.clienteVenta == null ? Icons.storefront : Icons.person,
                                color: R.forest,
                              ),
                              title: Text(
                                store.clienteVenta == null ? 'Venta de mostrador' : store.clienteVenta!.nombre,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                store.clienteVenta == null
                                    ? 'Cliente de paso. Toca para venderle a alguien guardado.'
                                    : [
                                  if (store.clienteVenta!.telefono.isNotEmpty) store.clienteVenta!.telefono,
                                  'Toca para cambiar',
                                ].join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _elegirCliente,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar producto o código...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => q = v),
                    ),
                  ),
                ),
                if (store.isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (visibles.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay productos.\nVe a Bodega y agrega el primero, o carga el ejemplo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) {
                          final p = visibles[i];
                          final id = p.id ?? -1;
                          final cant = store.cantidadEnCarrito(id);
                          final item = store.carrito.where((c) => c.productoId == id);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            Text(
                                              '${p.codigoRef} · ${pesos(store.tipoCarrito == 'ENTRADA' ? p.costo : p.precioVenta)}',
                                              style: const TextStyle(fontSize: 12, color: R.muted),
                                            ),
                                            const SizedBox(height: 6),
                                            StockMeter(producto: p),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: cant > 0 ? () => store.quitarCarrito(id) : null,
                                        icon: const Icon(Icons.remove, color: R.danger),
                                      ),
                                      InkWell(
                                        onTap: () => _editarCantidad(id, cant),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: Text(
                                            '$cant',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          final r = store.addCarrito(id);
                                          if (!r.ok && r.reason == 'stock') {
                                            _toast('No hay suficiente cantidad para sacar');
                                          }
                                        },
                                        icon: const Icon(Icons.add, color: R.forest),
                                      ),
                                    ],
                                  ),
                                  if (store.tipoCarrito == 'ENTRADA' && cant > 0 && item.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Costo de esta compra (unidad)',
                                          isDense: true,
                                        ),
                                        controller: TextEditingController(text: '${item.first.costoUnitario.round()}'),
                                        onChanged: (v) => store.setCostoItem(id, double.tryParse(v.replaceAll(',', '.')) ?? 0),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: visibles.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Material(
            color: const Color(0x141B4D3E),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.tipoCarrito == 'ENTRADA'
                              ? 'Costo de lo que entra · $items'
                              : 'Costo de lo que sale · $items',
                          style: const TextStyle(fontSize: 11, color: R.muted),
                        ),
                        Text('TOTAL ${pesos(valor)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: R.forest)),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: store.tipoCarrito == 'ENTRADA' ? R.ok : R.ink,
                      minimumSize: const Size(120, 48),
                    ),
                    onPressed: store.carrito.isEmpty
                        ? null
                        : () async {
                      final tipo = store.tipoCarrito;
                      final quien = store.clienteVenta?.nombre;
                      final r = await store.finalizarCarrito();
                      if (!r.ok) {
                        if (r.reason == 'vacio') {
                          _toast('Suma al menos un producto con el +');
                        } else if (r.reason == 'stock') {
                          _toast('No hay suficiente${r.codigoRef != null ? ' de ${r.codigoRef}' : ''}');
                        } else {
                          _toast('No se pudo registrar');
                        }
                        return;
                      }
                      referencia.clear();
                      proveedor.clear();
                      _toast(tipo == 'ENTRADA'
                          ? 'Mercancía registrada · ${r.count}'
                          : (quien == null || quien.isEmpty
                          ? 'Venta de mostrador · ${r.count}'
                          : 'Venta a $quien · ${r.count}'));
                    },
                    child: const Text('Registrar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String label;
  final String hint;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TipoBtn({
    required this.label,
    required this.hint,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? color : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : R.muted)),
            Text(hint, style: TextStyle(fontSize: 10, color: active ? Colors.white70 : R.muted)),
          ],
        ),
      ),
    );
  }
}