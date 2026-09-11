import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/format.dart';
import '../data/reports.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/ad_gate.dart';
import '../widgets/stock_meter.dart';

class BodegaPantalla extends StatefulWidget {
  const BodegaPantalla({super.key});

  @override
  State<BodegaPantalla> createState() => _BodegaPantallaState();
}

class _BodegaPantallaState extends State<BodegaPantalla> {
  String q = '';
  String filtro = 'todos';

  Future<void> _abrirForm({Producto? producto}) async {
    final store = context.read<Store>();
    if (producto == null && !store.negocio.esPro && store.productos.length >= limiteSkuGratis) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En la versión gratis caben $limiteSkuGratis productos. Pásate a Pro.'),
          backgroundColor: R.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ProductoForm(
          producto: producto,
          onSave: (p) async {
            try {
              if (producto == null) {
                if (!mounted) return;
                final seguir = await anuncioSiGratis(context, esPro: store.negocio.esPro);
                if (!seguir || !mounted) return;
                final r = await store.agregarProducto(p);
                if (!mounted) return;
                if (!r.ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        r.reason == 'limite'
                            ? 'Ya llegaste al tope de $limiteSkuGratis productos'
                            : 'No pude guardar el producto',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
              } else {
                await store.actualizarProducto(p);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(producto == null ? 'Producto guardado' : 'Producto actualizado'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No pude guardar. Revisa los datos e intenta de nuevo.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final n = q.trim().toLowerCase();
    final lista = store.productos.where((p) {
      final hit = n.isEmpty ||
          p.nombre.toLowerCase().contains(n) ||
          p.codigoRef.toLowerCase().contains(n) ||
          p.proveedor.toLowerCase().contains(n);
      if (!hit) return false;
      final nivel = nivelStock(p);
      if (filtro == 'bajo') return nivel == NivelStock.bajo;
      if (filtro == 'agotado') return nivel == NivelStock.agotado;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          store.negocio.esPro
              ? 'Productos · ${store.productos.length}'
              : 'Productos · ${store.productos.length} / $limiteSkuGratis',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, código o proveedor...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                for (final e in [
                  ('todos', 'Todos'),
                  ('bajo', 'Por acabarse'),
                  ('agotado', 'Se acabaron'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: filtro == e.$1,
                      selectedColor: R.forest,
                      labelStyle: TextStyle(color: filtro == e.$1 ? Colors.white : R.ink),
                      onSelected: (_) => setState(() => filtro = e.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: store.isLoading
                ? const Center(child: CircularProgressIndicator())
                : store.errorCarga != null
                ? _Vacio(
              texto: store.errorCarga!,
              boton: 'Reintentar',
              onTap: store.cargarProductos,
            )
                : lista.isEmpty
                ? _Vacio(
              texto: store.productos.isEmpty
                  ? 'Tu bodega está vacía.\nAgrega tu primer producto con el botón +.\nEn Ajustes puedes cargar una tienda de prueba para verla llena.'
                  : 'Nada coincide con la búsqueda.',
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final p = lista[i];
                final nivel = nivelStock(p);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(p.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (nivel == NivelStock.agotado) const _Chip('Se acabó', R.danger),
                        if (nivel == NivelStock.bajo) const _Chip('Pocas', R.warn),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.codigoRef} · ${p.categoria} · ${p.ubicacion}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        StockMeter(producto: p),
                      ],
                    ),
                    trailing: Text(pesos(p.precioVenta), style: const TextStyle(fontWeight: FontWeight.w800, color: R.forest)),
                    onTap: () => _abrirForm(producto: p),
                    onLongPress: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Quitar de la lista'),
                          content: Text('¿Quitar ${p.nombre}? El historial de movimientos se conserva.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Quitar')),
                          ],
                        ),
                      );
                      if (ok == true && p.id != null) await store.eliminarProducto(p.id!);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String texto;
  final String? boton;
  final VoidCallback? onTap;
  const _Vacio({required this.texto, this.boton, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (boton != null && onTap != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: R.forest),
                onPressed: onTap,
                child: Text(boton!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class ProductoForm extends StatefulWidget {
  final Producto? producto;
  final Future<void> Function(Producto) onSave;
  const ProductoForm({super.key, this.producto, required this.onSave});

  @override
  State<ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<ProductoForm> {
  late final TextEditingController nombre;
  late final TextEditingController codigo;
  late final TextEditingController costo;
  late final TextEditingController precio;
  late final TextEditingController stock;
  late final TextEditingController minimo;
  late final TextEditingController proveedor;
  late final TextEditingController ubicacion;
  late String categoria;
  late String unidad;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    final store = context.read<Store>();
    categoria = p?.categoria ?? 'Mercado';
    unidad = p?.unidad ?? 'und';
    nombre = TextEditingController(text: p?.nombre ?? '');
    codigo = TextEditingController(text: p?.codigoRef ?? store.codigoSiguiente(categoria));
    costo = TextEditingController(text: p == null ? '' : '${p.costo.round()}');
    precio = TextEditingController(text: p == null ? '' : '${p.precioVenta.round()}');
    stock = TextEditingController(text: p == null ? '' : '${p.stockActual}');
    minimo = TextEditingController(text: p == null ? '10' : '${p.stockMinimo}');
    proveedor = TextEditingController(text: p?.proveedor ?? '');
    ubicacion = TextEditingController(text: p?.ubicacion ?? '');
  }

  @override
  void dispose() {
    nombre.dispose();
    codigo.dispose();
    costo.dispose();
    precio.dispose();
    stock.dispose();
    minimo.dispose();
    proveedor.dispose();
    ubicacion.dispose();
    super.dispose();
  }

  Future<void> _nuevaCategoria() async {
    final ctrl = TextEditingController();
    final nombreNuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Medicamentos, Confitería...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.forest),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombreNuevo == null || nombreNuevo.isEmpty || !mounted) return;
    final store = context.read<Store>();
    final r = await store.crearCategoria(nombreNuevo);
    if (!mounted) return;
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(r.reason == 'existe' ? 'Esa categoría ya existe' : 'No pude crear la categoría'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      categoria = store.categoriasTodas.firstWhere(
            (c) => c.toLowerCase() == nombreNuevo.toLowerCase(),
        orElse: () => nombreNuevo,
      );
      if (widget.producto == null) {
        codigo.text = store.codigoSiguiente(categoria);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Categoría lista · código ${r.codigoRef}-001'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quitarCategoria(String nombreCat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar categoría'),
        content: Text(
          '«$nombreCat» ya no saldrá al crear productos. Los que ya la tienen se quedan igual.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar', style: TextStyle(color: R.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<Store>();
    final r = await store.eliminarCategoria(nombreCat);
    if (!mounted || !r.ok) return;
    setState(() {
      if (categoria == nombreCat) {
        categoria = 'Mercado';
        if (widget.producto == null) {
          codigo.text = store.codigoSiguiente(categoria);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    final store = context.watch<Store>();
    final cats = store.categoriasTodas;
    final catActual = cats.contains(categoria) ? categoria : (cats.isEmpty ? 'Mercado' : cats.first);
    final esCustom = store.categoriasExtra.keys.any((k) => k.toLowerCase() == categoria.toLowerCase());
    return Material(
      child: SizedBox(
        height: alto * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.producto == null ? 'Nuevo producto' : 'Editar producto',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  TextField(controller: nombre, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nombre')),
                  DropdownButtonFormField<String>(
                    key: ValueKey('cat-$catActual-${cats.length}'),
                    initialValue: catActual,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(
                        value: kAgregarCategoria,
                        child: Text(
                          '+  Agregar categoría',
                          style: TextStyle(color: R.forest, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      if (v == kAgregarCategoria) {
                        await _nuevaCategoria();
                        return;
                      }
                      setState(() {
                        categoria = v;
                        if (widget.producto == null) {
                          codigo.text = store.codigoSiguiente(v);
                        }
                      });
                    },
                  ),
                  if (esCustom)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: R.muted,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _quitarCategoria(categoria),
                        child: const Text('Quitar de la lista', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  TextField(
                    controller: codigo,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      labelText: 'Código (lo arma la app)',
                      helperText: 'Cambia solo si cambias la categoría',
                      filled: true,
                      fillColor: Color(0xFFF3EFE6),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: unidad,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unidad (und, kg, lt...)'),
                    items: unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => unidad = v ?? 'und'),
                  ),
                  TextField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad actual', hintText: '0'),
                  ),
                  TextField(
                    controller: minimo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Se agota a partir de', hintText: '10'),
                  ),
                  TextField(
                    controller: costo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Lo que me costó (\$)', hintText: '1800'),
                  ),
                  TextField(
                    controller: precio,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'A cómo lo vendo (\$)', hintText: '2500'),
                  ),
                  TextField(controller: proveedor, decoration: const InputDecoration(labelText: 'Proveedor')),
                  TextField(controller: ubicacion, decoration: const InputDecoration(labelText: 'Ubicación del producto', hintText: 'Estante / vitrina')),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: R.forest),
                    onPressed: guardando
                        ? null
                        : () async {
                      if (nombre.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Escribe el nombre del producto'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() => guardando = true);
                      await widget.onSave(Producto(
                        id: widget.producto?.id,
                        codigoRef: widget.producto?.codigoRef ??
                            (codigo.text.trim().isEmpty
                                ? context.read<Store>().codigoSiguiente(categoria)
                                : codigo.text.trim()),
                        nombre: nombre.text.trim(),
                        categoria: categoria,
                        unidad: unidad,
                        stockActual: int.tryParse(stock.text) ?? 0,
                        stockMinimo: int.tryParse(minimo.text) ?? 10,
                        costo: double.tryParse(costo.text.replaceAll(',', '.')) ?? 0,
                        precioVenta: double.tryParse(precio.text.replaceAll(',', '.')) ?? 0,
                        proveedor: proveedor.text.trim(),
                        ubicacion: ubicacion.text.trim(),
                      ));
                      if (mounted) setState(() => guardando = false);
                    },
                    child: Text(guardando ? 'Guardando...' : 'Guardar'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}