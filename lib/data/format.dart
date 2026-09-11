const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String pesos(num valor) {
  final n = valor.round();
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}\$$buf';
}

String fechaCorta(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$d ${_meses[dt.month - 1]} ${dt.year}  $h:$m';
}

String fechaArchivo(DateTime d) => '${d.day}-${_meses[d.month - 1]}-${d.year}';

String mesArchivo(DateTime d) => '${_meses[d.month - 1]}-${d.year}';

String hoyISO() => DateTime.now().toIso8601String();