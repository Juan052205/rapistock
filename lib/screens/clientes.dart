import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';

class ClientesPantalla extends StatefulWidget {
  static const Object mostrador = Object();
  final bool elegir;
  const ClientesPantalla({super.key, this.elegir = false});

  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> {
  String q = '';

  Future<void> _form({Cliente? c}) async {
    final store = context.read<Store>();
    if (c == null && !store.negocio.esPro && store.clientes.length >= limiteClientesGratis) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En gratis caben $limiteClientesGratis clientes. Pásate a Pro.'),
          backgroundColor: R.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final nombre = TextEditingController(text: c?.nombre ?? '');
    final tel = TextEditingController(text: c?.telefono ?? '');
    final nit = TextEditingController(text: c?.nit ?? '');
    final dir = TextEditingController(text: c?.direccion ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final kb = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: kb),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c == null ? 'Nuevo cliente' : 'Editar cliente',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombre,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Doña Rosa'),
                  ),
                  TextField(
                    controller: tel,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Celular (opcional)'),
                  ),
                  TextField(
                    controller: nit,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Cédula o NIT (opcional)'),
                  ),
                  TextField(
                    controller: dir,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Barrio o dirección (opcional)'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: R.forest,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    if (nombre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final nuevo = Cliente(
      id: c?.id,
      nombre: nombre.text.trim(),
      telefono: tel.text.trim(),
      nit: nit.text.trim(),
      direccion: dir.text.trim(),
    );
    final r = c == null ? await store.agregarCliente(nuevo) : await store.actualizarCliente(nuevo);
    if (!mounted) return;
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(r.reason == 'limite' ? 'Tope de clientes en la versión gratis' : 'No pude guardar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (widget.elegir && c == null) {
      final creado = store.clientes.where((x) => x.nombre == nuevo.nombre).toList();
      if (creado.isNotEmpty) Navigator.pop(context, creado.last);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final n = q.trim().toLowerCase();
    final lista = store.clientes.where((c) {
      if (n.isEmpty) return true;
      return c.nombre.toLowerCase().contains(n) ||
          c.telefono.contains(n) ||
          c.nit.toLowerCase().contains(n);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.elegir ? '¿A quién se le vendió?' : 'Clientes · ${store.clientes.length}'),
      ),
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nombre, celular o cédula...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          if (widget.elegir)
            ListTile(
              leading: const Icon(Icons.storefront, color: R.forest),
              title: const Text('Venta de mostrador', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Cliente de paso, sin guardar nombre'),
              onTap: () => Navigator.pop(context, ClientesPantalla.mostrador),
            ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Todavía no hay clientes.\nToca + Cliente.', textAlign: TextAlign.center))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final c = lista[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: R.forest,
                      child: Text(
                        c.nombre.isEmpty ? '?' : c.nombre[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [
                        if (c.telefono.isNotEmpty) c.telefono,
                        if (c.nit.isNotEmpty) c.nit,
                        if (c.direccion.isNotEmpty) c.direccion,
                      ].join(' · ').ifEmpty('Sin datos extra'),
                    ),
                    onTap: () {
                      if (widget.elegir) {
                        Navigator.pop(context, c);
                      } else {
                        _form(c: c);
                      }
                    },
                    onLongPress: widget.elegir
                        ? null
                        : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Quitar cliente'),
                          content: Text('¿Quitar a ${c.nombre}? Las ventas ya hechas se conservan.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
                          ],
                        ),
                      );
                      if (ok == true && c.id != null) await store.eliminarCliente(c.id!);
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

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}