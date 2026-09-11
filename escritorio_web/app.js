var DB = "https://rapistock-default-rtdb.firebaseio.com";
var k = (new URLSearchParams(location.search).get("k") || "").toUpperCase();
var app = document.getElementById("app");
var state = null;
var busy = false;
var dirty = false;
var tab = "bodega";
var q = "";
var filtro = "todos";
var tipoMov = "SALIDA";
var motivo = "Venta";
var referencia = "";
var carrito = {};
var histTipo = "todos";
var histQ = "";
var formRef = null;
var formCli = null;
var conteo = {};
var xlDesde = "";
var xlHasta = "";
var histRango = "todos";
var histDesde = "";
var histHasta = "";
var histCli = "";
var histProd = "";
var clienteVenta = null;
var cliQ = "";
var DEV_ID = localStorage.getItem("rs_dev");
if (!DEV_ID){
  DEV_ID = "pc_"+Date.now().toString(36)+Math.random().toString(36).slice(2,7);
  localStorage.setItem("rs_dev", DEV_ID);
}
var JOIN_KEY = "rs_ok_"+k;
var MAX_PC = 2;
var sesionOk = false;

(function(){
  if (document.getElementById("rs-extra")) return;
  var s = document.createElement("style");
  s.id = "rs-extra";
  s.textContent = ".stick{position:sticky;top:0;z-index:30;box-shadow:0 8px 18px #1B4D3E33}"
    +".toast{position:fixed;left:50%;bottom:96px;transform:translateX(-50%);z-index:80;max-width:92%;padding:12px 18px;border-radius:12px;font-weight:700;box-shadow:0 10px 30px #0004;display:none}"
    +".qtyN{min-width:36px;text-align:center;display:inline-block;cursor:pointer;text-decoration:underline;padding:4px 8px;font-weight:800}"
    +".qty input{width:72px;text-align:center;font-weight:800}"
    +".dock{position:fixed;left:0;right:0;bottom:0;z-index:25;background:#fff;border-top:1px solid #e5e0d6;padding:10px 16px 14px;box-shadow:0 -8px 24px #1B4D3E22}"
    +".dock .row{max-width:1120px;margin:0 auto;align-items:center}"
    +".cnt-ok{margin-left:8px;white-space:nowrap}";
  document.head.appendChild(s);
})();
var CATS = ["Mercado","Lácteos","Bebidas","Aseo","Mecato","Ferretería","Otros"];
var PREF = {Mercado:"ME","Lácteos":"LA",Bebidas:"BE",Aseo:"AS",Mecato:"MC","Ferretería":"FE",Otros:"OT"};
var UNID = ["und","kg","lt","bulto","caja","paq"];
var MOT_IN = ["Compra a proveedor","Devolucion de cliente","Traslado recibido","Ajuste de conteo"];
var MOT_OUT = ["Venta","Merma / vencimiento","Uso interno","Traslado enviado","Devolucion a proveedor"];

function pesos(n){
  var v = Math.round(Number(n)||0), neg = v<0, s = String(Math.abs(v)), b="";
  for (var i=0;i<s.length;i++){ if(i>0 && (s.length-i)%3===0) b+="."; b+=s[i]; }
  return (neg?"-":"")+"$"+b;
}
function esc(s){
  return String(s||"").replace(/[&<>"']/g, function(c){
    return ({"&":"&#38;","<":"&#60;",">":"&#62;",'"':"&#34;","'":"&#39;"})[c];
  });
}
function slugNeg(){
  var n = ((state.negocio||{}).nombre||"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"");
  return n || "rapistock";
}
function slugFecha(d){
  var meses=["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"];
  return d.getDate()+"-"+meses[d.getMonth()]+"-"+d.getFullYear();
}
function mesArchivo(d){
  var meses=["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"];
  return meses[d.getMonth()]+"-"+d.getFullYear();
}
function hoyISO(){ return new Date().toISOString(); }
function fechaCorta(raw){
  var d = new Date(raw); if (isNaN(d)) return raw||"";
  var meses=["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"];
  return String(d.getDate()).padStart(2,"0")+" "+meses[d.getMonth()]+" "+d.getFullYear()+"  "+String(d.getHours()).padStart(2,"0")+":"+String(d.getMinutes()).padStart(2,"0");
}
function dbUrl(){ return DB.replace(/\/$/,"")+"/sesiones/"+encodeURIComponent(k)+".json"; }
function sesionDevUrl(){ return DB.replace(/\/$/,"")+"/sesiones/"+encodeURIComponent(k)+"/sesion/dispositivos/"+encodeURIComponent(DEV_ID)+".json"; }
function nombrePc(){
  var p = (navigator.platform||"PC").replace(/_/g," ");
  return "Computador "+p.slice(0,18);
}
function latido(){
  return fetch(sesionDevUrl(), {
    method:"PUT",
    headers:{"Content-Type":"application/json"},
    body: JSON.stringify({nombre: nombrePc(), lastSeen: Date.now()})
  }).catch(function(){});
}
function card(t,x){ app.innerHTML = '<div class="center"><div class="cardc"><h1>'+esc(t)+"</h1><p>"+esc(x)+"</p></div></div>"; }
function aviso(t, mal){
  var el = document.getElementById("toast");
  if (!el){
    el = document.createElement("div");
    el.id = "toast";
    document.body.appendChild(el);
  }
  el.className = "toast " + (mal ? "badb" : "okb");
  el.textContent = t;
  el.style.display = "block";
  clearTimeout(window._toastT);
  window._toastT = setTimeout(function(){ el.style.display = "none"; }, 2800);
}
function prod(ref){ var a=state.productos||[]; for(var i=0;i<a.length;i++) if(a[i].codigoRef===ref) return a[i]; return null; }
function catsTodas(){
  var extra = state.categoriasExtra || {};
  var out = CATS.slice();
  Object.keys(extra).forEach(function(n){ if(!out.some(function(c){ return c.toLowerCase()===n.toLowerCase(); })) out.push(n); });
  (state.productos||[]).forEach(function(p){ if(p.categoria && !out.some(function(c){ return c.toLowerCase()===p.categoria.toLowerCase(); })) out.push(p.categoria); });
  return out;
}
function prefijosUsados(){
  var s = {}, extra = state.categoriasExtra||{};
  Object.keys(PREF).forEach(function(c){ s[PREF[c]]=1; });
  Object.keys(extra).forEach(function(c){ s[String(extra[c]).toUpperCase()]=1; });
  return s;
}
function genPref(nombre){
  var tomados = prefijosUsados();
  var letras = String(nombre||"").toUpperCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^A-Z]/g,"");
  if (letras.length>=2){
    var p = letras.slice(0,2); if(!tomados[p]) return p;
    for (var i=1;i<letras.length;i++){ p=letras[0]+letras[i]; if(!tomados[p]) return p; }
  }
  var abc="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for (var a=0;a<26;a++) for (var b=0;b<26;b++){ p=abc[a]+abc[b]; if(!tomados[p]) return p; }
  return "ZZ";
}
function prefDe(cat){
  if (PREF[cat]) return PREF[cat];
  var extra = state.categoriasExtra||{};
  if (extra[cat]) return extra[cat];
  return genPref(cat);
}
function sigCodigo(cat){
  var pref = prefDe(cat), max=0;
  (state.productos||[]).forEach(function(p){
    if (String(p.codigoRef).toUpperCase().indexOf(pref+"-")===0){
      var n = parseInt(String(p.codigoRef).split("-").pop(),10)||0; if(n>max) max=n;
    }
  });
  return pref+"-"+String(max+1).padStart(3,"0");
}
function valorInv(){ var t=0; (state.productos||[]).forEach(function(p){ t+=(p.stockActual||0)*(p.costo||0); }); return t; }
function valorPot(){ var t=0; (state.productos||[]).forEach(function(p){ t+=(p.stockActual||0)*(p.precioVenta||0); }); return t; }
function movHoy(){
  var now=new Date(), out=[];
  (state.movimientos||[]).forEach(function(m){
    var d=new Date(m.fecha);
    if(d.getFullYear()===now.getFullYear() && d.getMonth()===now.getMonth() && d.getDate()===now.getDate()) out.push(m);
  });
  return out;
}

async function load(){
  if (!k){ card("Rapistock","Falta el codigo. Escanea el QR desde el celular o abre el link completo."); return; }
  if (busy || dirty || formRef!==null || formCli!==null) return;
  var ae = document.activeElement;
  if (ae && (ae.tagName==="INPUT" || ae.tagName==="SELECT" || ae.tagName==="TEXTAREA") && ae.id!=="q" && ae.id!=="hq" && ae.id!=="cq") return;
  try{
    var r = await fetch(dbUrl());
    var data = await r.json();
    if (!data){ card("Sala vacia","Abre Rapistock en el celular (con internet) y toca Mostrar codigo. Luego recarga."); return; }

    var ses = data.sesion || {};
    if (ses.activa === false){
      localStorage.removeItem(JOIN_KEY);
      sesionOk = false;
      card("El dueño cerró esta sala","Desde el celular se cerraron los computadores. Pídele el QR nuevo (Ajustes → Usar en el computador).");
      return;
    }
    if (data.negocio && data.negocio.esPro === false){
      sesionOk = false;
      card("Rapistock Pro","Esta página es solo para la cuenta Pro. Actívala en el celular y vuelve a abrir el link.");
      return;
    }
    var max = ses.maxDispositivos || MAX_PC;
    var devs = ses.dispositivos;
    if (!devs || typeof devs !== "object" || Array.isArray(devs)) devs = {};
    if (devs[DEV_ID]){
      localStorage.setItem(JOIN_KEY, "1");
      latido();
      sesionOk = true;
    } else if (localStorage.getItem(JOIN_KEY) === "1"){
      sesionOk = false;
      card("Este computador se desconectó","El dueño lo quitó desde el celular. Pídele el link otra vez.");
      return;
    } else {
      var n = 0;
      Object.keys(devs).forEach(function(id){ if (devs[id]) n++; });
      if (n >= max){
        sesionOk = false;
        card("Ya hay "+max+" computadores","Rapistock Pro permite "+max+" PCs a la vez. En el celular: Ajustes → Usar en el computador → quita uno o cierra todos.");
        return;
      }
      await latido();
      localStorage.setItem(JOIN_KEY, "1");
      sesionOk = true;
    }

    if (state && data.rev && state.rev && data.rev < state.rev) return;
    state = data;
    if (!state.productos) state.productos=[];
    if (!state.movimientos) state.movimientos=[];
    if (!state.negocio) state.negocio={};
    if (!state.categoriasExtra) state.categoriasExtra={};
    if (!state.clientes) state.clientes=[];
    if (!state.sesion) state.sesion = {activa:true, maxDispositivos:max, dispositivos:devs};
    render();
  } catch(e){ if(!state) card("Sin conexion","Revisa internet y recarga."); }
}
async function save(){
  if (!sesionOk) return;
  state.rev = Date.now();
  state.sesion = state.sesion || {activa:true, maxDispositivos:MAX_PC, dispositivos:{}};
  state.sesion.activa = true;
  if (!state.sesion.dispositivos) state.sesion.dispositivos = {};
  state.sesion.dispositivos[DEV_ID] = {nombre: nombrePc(), lastSeen: Date.now()};
  var r = await fetch(dbUrl(), { method:"PUT", headers:{"Content-Type":"application/json"}, body: JSON.stringify(state) });
  if (!r.ok) throw new Error("save");
}
function mover(codigoRef, tipo, cantidad, mot, ref){
  if (busy || !state) return;
  var cant = Math.max(1, parseInt(cantidad,10)||1);
  var p = prod(codigoRef);
  if (!p){ aviso("Producto no esta", true); return; }
  var permitir = !!(state.negocio && state.negocio.permitirStockNegativo);
  if (tipo==="SALIDA" && p.stockActual < cant && !permitir){ aviso("No hay tantas unidades de "+p.nombre, true); return; }
  busy = true;
  var antes = p.stockActual;
  var despues = tipo==="ENTRADA" ? antes+cant : antes-cant;
  p.stockActual = despues;
  state.movimientos = [{
    productoId: p.id, productoNombre: p.nombre, codigoRef: p.codigoRef,
    tipoMovimiento: tipo, cantidad: cant, stockAntes: antes, stockDespues: despues,
    motivo: mot || (tipo==="ENTRADA"?"Compra a proveedor":"Venta"),
    referencia: ref || "Computador", fecha: hoyISO(),
    clienteId: tipo==="SALIDA" && clienteVenta ? clienteVenta.id : null,
    clienteNombre: tipo==="SALIDA" && clienteVenta ? (clienteVenta.nombre||"") : ""
  }].concat(state.movimientos||[]);
  save().then(function(){ aviso("Listo: "+(tipo==="SALIDA"?"salio":"entro")+" "+cant+" · "+p.nombre); render(); })
    .catch(function(){ aviso("No pude guardar. Revisa internet.", true); })
    .finally(function(){ busy=false; });
}

function guardarProducto(p, esNuevo){
  if (!p.nombre){ aviso("Escribe el nombre", true); return; }
  if (esNuevo){
    if (!p.codigoRef) p.codigoRef = sigCodigo(p.categoria||"Mercado");
    p.id = Date.now();
    state.productos = (state.productos||[]).concat([p]);
  } else {
    state.productos = (state.productos||[]).map(function(x){ return x.codigoRef===p.codigoRef ? p : x; });
  }
  formRef = null; dirty=false;
  busy=true;
  save().then(function(){ aviso(esNuevo?"Producto guardado":"Producto actualizado"); render(); })
    .catch(function(){ aviso("No pude guardar", true); })
    .finally(function(){ busy=false; });
}
function quitarProducto(ref){
  if (!confirm("¿Quitar "+(prod(ref)||{}).nombre+"? El historial se conserva.")) return;
  state.productos = (state.productos||[]).filter(function(p){ return p.codigoRef!==ref; });
  save().then(function(){ aviso("Producto quitado"); render(); });
}
function registrarCarrito(){
  var refs = Object.keys(carrito);
  if (!refs.length){ aviso("Suma al menos un producto con el +", true); return; }
  var permitir = !!(state.negocio && state.negocio.permitirStockNegativo);
  for (var i=0;i<refs.length;i++){
    var p = prod(refs[i]); var c = carrito[refs[i]];
    if (!p) continue;
    if (tipoMov==="SALIDA" && c.cant > p.stockActual && !permitir){ aviso("No hay suficiente de "+p.nombre, true); return; }
  }
  busy=true;
  var n=0;
  refs.forEach(function(ref){
    var p = prod(ref); if(!p) return;
    var c = carrito[ref];
    var antes = p.stockActual;
    var despues = tipoMov==="ENTRADA" ? antes+c.cant : antes-c.cant;
    if (tipoMov==="ENTRADA" && c.costo>0){
      var den = antes+c.cant;
      p.costo = den>0 ? (antes*p.costo + c.cant*c.costo)/den : c.costo;
    }
    p.stockActual = despues;
    state.movimientos = [{
      productoId:p.id, productoNombre:p.nombre, codigoRef:p.codigoRef,
      tipoMovimiento:tipoMov, cantidad:c.cant, stockAntes:antes, stockDespues:despues,
      motivo: motivo, referencia: referencia||"Computador", fecha: hoyISO(),
      clienteId: tipoMov==="SALIDA" && clienteVenta ? clienteVenta.id : null,
      clienteNombre: tipoMov==="SALIDA" && clienteVenta ? (clienteVenta.nombre||"") : ""
    }].concat(state.movimientos||[]);
    n++;
  });
  carrito = {};
  var quien = (tipoMov==="SALIDA" && clienteVenta) ? (" a "+clienteVenta.nombre) : "";
  save().then(function(){ aviso(tipoMov==="ENTRADA"?"Mercancia registrada · "+n:"Venta"+quien+" · "+n); render(); })
    .catch(function(){ aviso("No pude guardar", true); })
    .finally(function(){ busy=false; });
}
function aplicarConteo(soloRef){
  var cambios=0;
  (state.productos||[]).forEach(function(p){
    if (soloRef && p.codigoRef!==soloRef) return;
    if (conteo[p.codigoRef]==null) return;
    var n = parseInt(String(conteo[p.codigoRef]).replace(/\D/g,""),10);
    if (isNaN(n) || n===p.stockActual) return;
    var antes=p.stockActual;
    p.stockActual=n<0?0:n;
    state.movimientos = [{
      productoId:p.id, productoNombre:p.nombre, codigoRef:p.codigoRef,
      tipoMovimiento:"AJUSTE", cantidad:Math.abs(p.stockActual-antes),
      stockAntes:antes, stockDespues:p.stockActual,
      motivo:"Ajuste de conteo", referencia:"Conteo del estante", fecha:hoyISO()
    }].concat(state.movimientos||[]);
    delete conteo[p.codigoRef];
    cambios++;
  });
  if (!cambios){ aviso("Sin diferencias todavia", true); return; }
  save().then(function(){ aviso("Conteo aplicado · "+cambios); render(); });
}
function conteoPendiente(){
  var p = state.productos||[];
  for (var i=0;i<p.length;i++){
    if (conteo[p[i].codigoRef]==null || conteo[p[i].codigoRef]==="") continue;
    var n=parseInt(String(conteo[p[i].codigoRef]).replace(/\D/g,""),10);
    if (!isNaN(n) && n!==p[i].stockActual) return true;
  }
  return false;
}
function confirmarSalidaConteo(next){
  if (tab!=="tablero" || next==="tablero" || !conteoPendiente()) return true;
  if (confirm("Hay cantidades del estante sin aplicar. Si sales, se pierden esos cambios. ¿Salir sin aplicar?")){
    conteo={};
    return true;
  }
  return false;
}
function encabezadoExcel(titulo){
  var n = state.negocio||{};
  var filas = [[titulo],["Negocio",(n.nombre||"").trim()||"Mi negocio"]];
  if ((n.nit||"").trim()) filas.push(["NIT", n.nit.trim()]);
  if ((n.direccion||"").trim()) filas.push(["Direccion", n.direccion.trim()]);
  filas.push(["Fecha del archivo", fechaCorta(hoyISO())]);
  filas.push([""]);
  return filas;
}
function xmlEsc(s){
  return String(s==null?"":s).replace(/[&<>"]/g, function(c){
    return ({"&":"&#38;","<":"&#60;",">":"&#62;",'"':"&#34;"})[c];
  });
}
function u8(s){ return new TextEncoder().encode(s); }
function crc32(buf){
  var t = window._crcT;
  if (!t){
    t = new Uint32Array(256);
    for (var n=0;n<256;n++){
      var c=n;
      for (var k=0;k<8;k++) c = (c&1) ? (0xEDB88320^(c>>>1)) : (c>>>1);
      t[n]=c>>>0;
    }
    window._crcT=t;
  }
  var crc=0^(-1);
  for (var i=0;i<buf.length;i++) crc = (crc>>>8) ^ t[(crc^buf[i])&255];
  return (crc^(-1))>>>0;
}
function zipStore(files){
  var locals=[], central=[], offset=0, d=new Date();
  var time=(d.getHours()<<11)|(d.getMinutes()<<5)|((d.getSeconds()/2)|0);
  var date=((d.getFullYear()-1980)<<9)|((d.getMonth()+1)<<5)|d.getDate();
  files.forEach(function(f){
    var name=u8(f.name), data=f.data, crc=crc32(data);
    var lh=new Uint8Array(30+name.length);
    var v=new DataView(lh.buffer);
    v.setUint32(0,0x04034b50,true); v.setUint16(4,20,true); v.setUint16(6,0x0800,true);
    v.setUint16(10,time,true); v.setUint16(12,date,true);
    v.setUint32(14,crc,true); v.setUint32(18,data.length,true); v.setUint32(22,data.length,true);
    v.setUint16(26,name.length,true); lh.set(name,30);
    locals.push(lh, data);
    var ch=new Uint8Array(46+name.length);
    var cv=new DataView(ch.buffer);
    cv.setUint32(0,0x02014b50,true); cv.setUint16(4,20,true); cv.setUint16(6,20,true); cv.setUint16(8,0x0800,true);
    cv.setUint16(12,time,true); cv.setUint16(14,date,true);
    cv.setUint32(16,crc,true); cv.setUint32(20,data.length,true); cv.setUint32(24,data.length,true);
    cv.setUint16(28,name.length,true); cv.setUint32(42,offset,true); ch.set(name,46);
    central.push(ch);
    offset += lh.length + data.length;
  });
  var csize=0; central.forEach(function(c){ csize+=c.length; });
  var eocd=new Uint8Array(22), ev=new DataView(eocd.buffer);
  ev.setUint32(0,0x06054b50,true); ev.setUint16(8,files.length,true); ev.setUint16(10,files.length,true);
  ev.setUint32(12,csize,true); ev.setUint32(16,offset,true);
  var parts=locals.concat(central); parts.push(eocd);
  var total=0; parts.forEach(function(p){ total+=p.length; });
  var out=new Uint8Array(total), o=0;
  parts.forEach(function(p){ out.set(p,o); o+=p.length; });
  return out;
}
function colX(i){
  var s=""; i++;
  while(i>0){ var m=(i-1)%26; s=String.fromCharCode(65+m)+s; i=Math.floor((i-1)/26); }
  return s;
}
function bajarExcel(nombre, filas){
  var maxC=1;
  filas.forEach(function(r){ if(r.length>maxC) maxC=r.length; });
  var headerRow=-1;
  for (var i=0;i<filas.length;i++){ if(filas[i].length>=5){ headerRow=i; break; } }
  var sheet = '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>';
  filas.forEach(function(row, r){
    sheet += '<row r="'+(r+1)+'">';
    row.forEach(function(val, c){
      var num = typeof val==="number" && isFinite(val);
      var st = (r===headerRow) ? 3 : (headerRow>=0 && r>headerRow) ? (num?5:4) : (r===0?1:(row.length===2&&c===0?2:0));
      var ref = colX(c)+(r+1);
      if (num) sheet += '<c r="'+ref+'" s="'+st+'" t="n"><v>'+val+"</v></c>";
      else sheet += '<c r="'+ref+'" s="'+st+'" t="inlineStr"><is><t xml:space="preserve">'+xmlEsc(val)+"</t></is></c>";
    });
    sheet += "</row>";
  });
  sheet += "</sheetData></worksheet>";
  var styles = '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    +'<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="14"/><color rgb="FF1B4D3E"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
    +'<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1B4D3E"/></patternFill></fill></fills>'
    +'<borders count="2"><border/><border><left style="thin"><color rgb="FFC8C8C8"/></left><right style="thin"><color rgb="FFC8C8C8"/></right><top style="thin"><color rgb="FFC8C8C8"/></top><bottom style="thin"><color rgb="FFC8C8C8"/></bottom></border></borders>'
    +'<cellXfs count="6">'
    +'<xf fontId="0" fillId="0" borderId="0"/>'
    +'<xf fontId="1" fillId="0" borderId="0"/>'
    +'<xf fontId="0" fillId="0" borderId="1" applyBorder="1" applyFont="1"><fontId>0</fontId></xf>'
    +'<xf fontId="2" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
    +'<xf fontId="0" fillId="0" borderId="1" applyBorder="1"/>'
    +'<xf fontId="0" fillId="0" borderId="1" applyBorder="1" applyNumberFormat="1" numFmtId="3"/>'
    +'</cellXfs></styleSheet>';
  var files = [
    {name:"[Content_Types].xml", data:u8('<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>')},
    {name:"_rels/.rels", data:u8('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')},
    {name:"xl/workbook.xml", data:u8('<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rapistock" sheetId="1" r:id="rId1"/></sheets></workbook>')},
    {name:"xl/_rels/workbook.xml.rels", data:u8('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>')},
    {name:"xl/styles.xml", data:u8(styles)},
    {name:"xl/worksheets/sheet1.xml", data:u8(sheet)}
  ];
  var blob = new Blob([zipStore(files)], {type:"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"});
  var a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = String(nombre).replace(/\.xlsx?$/i,"")+".xlsx";
  a.click();
}
function excelProductos(){
  var filas = encabezadoExcel("Lista de productos");
  filas.push(["Codigo","Nombre","Categoria","Unidad","Cantidad","Minimo","Costo","Precio de venta","Valor","Proveedor","Ubicacion"]);
  (state.productos||[]).forEach(function(p){
    filas.push([p.codigoRef,p.nombre,p.categoria,p.unidad,p.stockActual,p.stockMinimo,Math.round(p.costo||0),Math.round(p.precioVenta||0),Math.round((p.stockActual||0)*(p.costo||0)),p.proveedor||"",p.ubicacion||""]);
  });
  bajarExcel("productos-"+slugNeg()+"-"+slugFecha(new Date())+".xls", filas);
}
function excelHistorial(desde, hasta, etiqueta){
  var filas = encabezadoExcel("Historial de movimientos");
  filas.push(["Fecha","Que paso","Codigo","Producto","Cantidad","Antes","Despues","Motivo","Factura o nota","Cliente"]);
  (state.movimientos||[]).forEach(function(m){
    var d = new Date(m.fecha); if (isNaN(d)) return;
    if (desde && d<desde) return;
    if (hasta && d>hasta) return;
    var t = m.tipoMovimiento==="ENTRADA"?"Entro": m.tipoMovimiento==="SALIDA"?"Salio":"Correccion";
    var cli = m.tipoMovimiento==="SALIDA" ? ((m.clienteNombre||"").trim() || "Mostrador (cliente de paso)") : "";
    filas.push([fechaCorta(m.fecha), t, m.codigoRef, m.productoNombre, m.cantidad, m.stockAntes, m.stockDespues, m.motivo||"", m.referencia||"", cli]);
  });
  if (filas.length<=8){ aviso("No hay movimientos en esas fechas", true); return false; }
  var suf = "todo-"+slugFecha(new Date());
  if (desde && hasta){
    suf = (etiqueta==="mes") ? mesArchivo(desde) : slugFecha(desde)+"-a-"+slugFecha(hasta);
  }
  bajarExcel("historial-"+slugNeg()+"-"+suf+".xls", filas);
  return true;
}
function shell(inner){
  var n = state.negocio||{};
  var nombre = (n.nombre||"").trim() || "Tu negocio";
  document.title = "Rapistock · "+nombre;
  var tabs = [["bodega","Bodega"],["mover","Mover"],["clientes","Clientes"],["historial","Historial"],["tablero","Tablero"],["ajustes","Ajustes"]];
  var nav = tabs.map(function(t){ return '<button class="'+(tab===t[0]?"on":"")+'" data-tab="'+t[0]+'">'+t[1]+"</button>"; }).join("");
  var extra = "";
  if ((n.nit||"").trim() || (n.direccion||"").trim()){
    extra = '<div class="meta">'
      +((n.nit||"").trim() ? "NIT "+esc(n.nit.trim()) : "")
      +((n.nit||"").trim() && (n.direccion||"").trim() ? " · " : "")
      +esc((n.direccion||"").trim())
      +"</div>";
  }
  return '<div class="stick"><header class="top"><div class="brand"><small>Rapistock Pro · computador</small><h1>'+esc(nombre)+'</h1>'+extra+'</div><div class="money"><div class="hero">'+pesos(valorInv())+'</div><div class="sub">en mercancía · si lo vendes todo '+pesos(valorPot())+"</div></div></header>"
    +'<nav class="tabs">'+nav+"</nav></div><main>"+inner+"</main>"
    +'<footer>El celular no tiene que estar abierto. Lo que hagas aqui llega a la app.</footer>';
}

function vistaBodega(){
  var lista = (state.productos||[]).filter(function(p){
    var t = (q||"").toLowerCase();
    var hit = !t || (p.nombre||"").toLowerCase().indexOf(t)>=0 || (p.codigoRef||"").toLowerCase().indexOf(t)>=0 || (p.proveedor||"").toLowerCase().indexOf(t)>=0;
    if (!hit) return false;
    if (filtro==="agotado") return p.stockActual<=0;
    if (filtro==="bajo") return p.stockActual>0 && p.stockActual<=(p.stockMinimo||10);
    return true;
  });
  var html = '<div class="chips"><button class="chip '+(filtro==="todos"?"on":"")+'" data-f="todos">Todos</button><button class="chip '+(filtro==="bajo"?"on":"")+'" data-f="bajo">Por acabarse</button><button class="chip '+(filtro==="agotado"?"on":"")+'" data-f="agotado">Se acabaron</button></div>';
  html += '<input id="q" placeholder="Buscar por nombre, codigo o proveedor..." value="'+esc(q)+'">';
  html += '<section><h2>Productos · '+(state.productos||[]).length+'</h2><div class="wrap"><table><thead><tr><th>Codigo</th><th>Nombre</th><th>Categoria</th><th class="n">Cant.</th><th class="n">Venta</th><th></th></tr></thead><tbody>';
  if (!lista.length) html += '<tr><td colspan="6">Nada por aqui. Toca + Producto.</td></tr>';
  lista.forEach(function(p){
    var est = p.stockActual<=0?'<span class="bad">Se acabo</span>': (p.stockActual<=(p.stockMinimo||10)?'<span class="warn">Pocas</span>':'');
    html += '<tr><td>'+esc(p.codigoRef)+'</td><td><b>'+esc(p.nombre)+'</b><div class="muted">'+esc(p.ubicacion||"")+'</div></td><td>'+esc(p.categoria)+'</td><td class="n">'+p.stockActual+'</td><td class="n">'+pesos(p.precioVenta)+'</td><td>'+est+' <button class="ghost" data-edit="'+esc(p.codigoRef)+'">Editar</button></td></tr>';
  });
  html += '</tbody></table></div></section><button class="fab" id="btnNuevo">+ Producto</button>';
  return html;
}

function vistaMover(){
  var motivos = tipoMov==="ENTRADA"?MOT_IN:MOT_OUT;
  if (motivos.indexOf(motivo)<0) motivo = motivos[0];
  var t = (q||"").toLowerCase();
  var vis = (state.productos||[]).filter(function(p){
    return !t || (p.nombre||"").toLowerCase().indexOf(t)>=0 || (p.codigoRef||"").toLowerCase().indexOf(t)>=0;
  });
  var items=0, valor=0;
  Object.keys(carrito).forEach(function(ref){
    var p=prod(ref); if(!p) return;
    items += carrito[ref].cant;
    valor += carrito[ref].cant * (tipoMov==="ENTRADA" ? (carrito[ref].costo||p.costo||0) : (p.costo||0));
  });
  var html = '<section><div class="row"><button class="'+(tipoMov==="ENTRADA"?"in":"ghost")+'" id="tIn">Entra · llego mercancia</button><button class="'+(tipoMov==="SALIDA"?"sale":"ghost")+'" id="tOut">Sale · se vendio</button></div>';
  html += '<div class="row" style="margin-top:10px"><label style="flex:2">Motivo<select id="motivo">';
  motivos.forEach(function(m){ html += '<option'+(m===motivo?" selected":"")+'>'+esc(m)+"</option>"; });
  html += '</select></label><label style="flex:2">Factura o nota (opcional)<input id="refmov" value="'+esc(referencia)+'" placeholder="'+(tipoMov==="ENTRADA"?"FC-1842":"V-2201")+'"></label></div>';
  if (tipoMov==="SALIDA"){
    html += '<div class="row" style="margin-top:8px"><label style="flex:1">¿A quién se le vendió?<select id="cliSel">';
    html += '<option value="">Venta de mostrador (cliente de paso)</option>';
    (state.clientes||[]).forEach(function(c){
      var sel = clienteVenta && String(clienteVenta.id)===String(c.id) ? " selected" : "";
      html += '<option value="'+esc(c.id)+'"'+sel+'>'+esc(c.nombre)+(c.telefono?" · "+esc(c.telefono):"")+"</option>";
    });
    html += '</select></label><button class="ghost" id="btnCliNuevo" type="button">+ Cliente</button></div>';
  }
  html += "</section>";
  html += '<input id="q" placeholder="Buscar producto o codigo..." value="'+esc(q)+'">';
  html += '<section class="list">';
  vis.forEach(function(p){
    var c = carrito[p.codigoRef] ? carrito[p.codigoRef].cant : 0;
    html += '<div class="item"><div style="flex:1"><b>'+esc(p.nombre)+'</b><span class="muted">'+esc(p.codigoRef)+' · '+pesos(tipoMov==="ENTRADA"?p.costo:p.precioVenta)+' · hay '+p.stockActual+'</span></div>';
    html += '<div class="qty"><button class="ghost" data-minus="'+esc(p.codigoRef)+'">-</button><b class="qtyN" data-qty="'+esc(p.codigoRef)+'">'+c+'</b><button class="go" data-plus="'+esc(p.codigoRef)+'">+</button></div></div>';
  });
  if (!vis.length) html += '<p class="muted">Todavia no hay productos.</p>';
  html += '</section>';
  html += '<div style="height:96px"></div>';
  html += '<div class="dock"><div class="row"><div style="flex:1"><div class="muted">'+(tipoMov==="ENTRADA"?"Costo de lo que entra":"Costo de lo que sale")+' · '+items+'</div><div class="hero" style="font-size:22px;color:var(--forest)">TOTAL '+pesos(valor)+'</div></div>';
  html += '<button class="go" id="btnReg" '+(items?"":"disabled")+'>Registrar</button></div></div>';
  return html;
}

function vistaHistorial(){
  var t = (histQ||"").toLowerCase();
  var lista = (state.movimientos||[]).filter(function(m){
    if (histTipo!=="todos" && m.tipoMovimiento!==histTipo) return false;
    var d = new Date(m.fecha);
    if (histRango==="hoy"){
      var n=new Date();
      if (d.getFullYear()!==n.getFullYear()||d.getMonth()!==n.getMonth()||d.getDate()!==n.getDate()) return false;
    } else if (histRango==="semana"){
      var n=new Date(); var lunes=new Date(n); lunes.setDate(n.getDate()-(n.getDay()||7)+1); lunes.setHours(0,0,0,0);
      var dom=new Date(lunes); dom.setDate(lunes.getDate()+6); dom.setHours(23,59,59,0);
      if (d<lunes || d>dom) return false;
    } else if (histRango==="mes"){
      var n=new Date();
      if (d.getFullYear()!==n.getFullYear()||d.getMonth()!==n.getMonth()) return false;
    } else if (histRango==="fechas" && histDesde && histHasta){
      if (d < new Date(histDesde+"T00:00:00") || d > new Date(histHasta+"T23:59:59")) return false;
    }
    if (histCli==="__mostrador__"){
      if (m.tipoMovimiento!=="SALIDA" || (m.clienteNombre||"").trim()) return false;
    } else if (histCli){
      if ((m.clienteNombre||"").trim().toLowerCase()!==String(histCli).toLowerCase()) return false;
    }
    if (histProd && (m.productoNombre||"").trim()!==histProd) return false;
    if (!t) return true;
    return (m.productoNombre||"").toLowerCase().indexOf(t)>=0 || (m.codigoRef||"").toLowerCase().indexOf(t)>=0 || (m.motivo||"").toLowerCase().indexOf(t)>=0 || (m.clienteNombre||"").toLowerCase().indexOf(t)>=0;
  });
  var cliSet = {}, prodSet = {};
  (state.clientes||[]).forEach(function(c){ if(c.nombre) cliSet[c.nombre]=1; });
  (state.movimientos||[]).forEach(function(m){
    if ((m.clienteNombre||"").trim()) cliSet[m.clienteNombre.trim()]=1;
    if ((m.productoNombre||"").trim()) prodSet[m.productoNombre.trim()]=1;
  });
  (state.productos||[]).forEach(function(p){ if(p.nombre) prodSet[p.nombre]=1; });
  var cliNombres = Object.keys(cliSet).sort(function(a,b){ return a.toLowerCase().localeCompare(b.toLowerCase()); });
  var prodNombres = Object.keys(prodSet).sort(function(a,b){ return a.toLowerCase().localeCompare(b.toLowerCase()); });

  var html = '<div class="row">';
  html += '<label style="flex:1">Cliente<select id="hCli"><option value="">Todos los clientes</option>';
  html += '<option value="__mostrador__"'+(histCli==="__mostrador__"?" selected":"")+'>Mostrador (de paso)</option>';
  cliNombres.forEach(function(c){ html += '<option value="'+esc(c)+'"'+(histCli===c?" selected":"")+'>'+esc(c)+"</option>"; });
  html += '</select></label>';
  html += '<label style="flex:1">Producto<select id="hProd"><option value="">Todos los productos</option>';
  prodNombres.forEach(function(p){ html += '<option value="'+esc(p)+'"'+(histProd===p?" selected":"")+'>'+esc(p)+"</option>"; });
  html += '</select></label></div>';
  html += '<div class="chips">';
  [["todos","Todos"],["hoy","Hoy"],["semana","Esta semana"],["mes","Este mes"],["fechas","Fechas"]].forEach(function(e){
    html += '<button class="chip '+(histRango===e[0]?"on":"")+'" data-hr="'+e[0]+'">'+e[1]+"</button>";
  });
  html += "</div>";
  if (histRango==="fechas") html += '<div class="row"><label>Desde<input type="date" id="hDesde" value="'+esc(histDesde)+'"></label><label>Hasta<input type="date" id="hHasta" value="'+esc(histHasta)+'"></label></div>';
  html += '<div class="chips"><button class="chip '+(histTipo==="todos"?"on":"")+'" data-ht="todos">Todos</button><button class="chip '+(histTipo==="ENTRADA"?"on":"")+'" data-ht="ENTRADA">Entro</button><button class="chip '+(histTipo==="SALIDA"?"on":"")+'" data-ht="SALIDA">Salio</button><button class="chip '+(histTipo==="AJUSTE"?"on":"")+'" data-ht="AJUSTE">Correcciones</button></div>';
  html += '<input id="hq" placeholder="Buscar texto: codigo, factura..." value="'+esc(histQ)+'">';
  var resumen = "";
  if (lista.length){
    if (histProd){
      var sal=0, ent=0;
      lista.forEach(function(m){ if(m.tipoMovimiento==="SALIDA") sal+=m.cantidad; if(m.tipoMovimiento==="ENTRADA") ent+=m.cantidad; });
      resumen = histProd+" · "+lista.length+" movimientos · salio "+sal+" · entro "+ent;
    } else if (histCli){
      resumen = (histCli==="__mostrador__"?"Mostrador (cliente de paso)":histCli)+" · "+lista.length+" movimientos en este filtro";
    } else {
      var cnt={};
      lista.forEach(function(m){ cnt[m.productoNombre]=(cnt[m.productoNombre]||0)+1; });
      var top=Object.keys(cnt).map(function(n){ return {n:n,u:cnt[n]}; }).sort(function(a,b){ return b.u-a.u; }).slice(0,3);
      if (top.length) resumen = "Lo que mas se movio: "+top.map(function(x){ return x.n+" ("+x.u+")"; }).join(" · ");
    }
  }
  if (resumen) html += '<p class="muted" style="color:var(--forest);font-weight:700">'+esc(resumen)+"</p>";
  var total = (state.movimientos||[]).length;
  if (total){
    html += '<section style="'+(total>=100?"background:#FFF4E5":"")+'"><h2>Si el listado se pone largo</h2>';
    html += '<p class="muted">Primero se descarga un Excel con TODO. Después se vacía el Historial y las barras de 7 días del Tablero quedan en cero. La bodega no se toca.</p>';
    html += '<button class="ghost" id="btnLimpiar">Guardar Excel y limpiar</button></section>';
  }
  html += '<section><h2>Historial · '+lista.length+(lista.length!==total?" / "+total:"")+'</h2><p class="muted">Aqui queda todo lo que entra, sale o se corrige. Filtra por cliente o producto para ver quien y cuando.</p><div class="wrap"><table><thead><tr><th>Que paso</th><th>Producto</th><th class="n">Cant.</th><th>Hora</th></tr></thead><tbody>';
  if (!lista.length) html += '<tr><td colspan="4">No hay movimientos en este filtro.</td></tr>';
  lista.slice(0,200).forEach(function(m){
    var et = m.tipoMovimiento==="ENTRADA"?"Entro": m.tipoMovimiento==="SALIDA"?"Salio":"Correccion";
    var extra = m.codigoRef||"";
    if (m.tipoMovimiento==="SALIDA") extra += " · "+(((m.clienteNombre||"").trim())||"Mostrador");
    if (m.motivo) extra += " · "+m.motivo;
    html += '<tr><td>'+et+'</td><td><b>'+esc(m.productoNombre)+'</b><div class="muted">'+esc(extra)+'</div></td><td class="n">'+(m.tipoMovimiento==="SALIDA"?"-":"+")+m.cantidad+'</td><td>'+esc(fechaCorta(m.fecha))+'</td></tr>';
  });
  html += '</tbody></table></div></section>';
  return html;
}

function vistaTablero(){
  var prods = state.productos||[], movs = state.movimientos||[];
  var ag=0,bj=0;
  prods.forEach(function(p){ if(p.stockActual<=0) ag++; else if(p.stockActual<=(p.stockMinimo||10)) bj++; });
  var hoy = movHoy();
  var html = '<div class="kpis"><div class="kpi"><span>Productos</span><b>'+prods.length+'</b></div><div class="kpi"><span>Hoy</span><b>'+hoy.length+'</b></div><div class="kpi"><span>Se acabaron</span><b>'+ag+'</b></div><div class="kpi"><span>Por acabarse</span><b>'+bj+'</b></div></div>';
  if (ag||bj){
    html += '<section><h2>Hay que revisar</h2>';
    prods.forEach(function(p){
      if (p.stockActual>0 && p.stockActual>(p.stockMinimo||10)) return;
      html += '<div class="item"><div style="flex:1"><b>'+esc(p.nombre)+'</b><span class="muted">'+esc(p.codigoRef)+' · '+p.stockActual+' / min. '+(p.stockMinimo||10)+'</span></div><span class="'+(p.stockActual<=0?"bad":"warn")+'">'+(p.stockActual<=0?"Se acabo":"Pocas")+'</span></div>';
    });
    html += '</section>';
  }
  var max=1, serie=[];
  for (var i=6;i>=0;i--){
    var d=new Date(); d.setDate(d.getDate()-i);
    var clave=d.getFullYear()+"-"+d.getMonth()+"-"+d.getDate();
    serie.push({clave:clave, et:["dom","lun","mar","mie","jue","vie","sab"][d.getDay()], e:0, s:0});
  }
  movs.forEach(function(m){
    var d=new Date(m.fecha); if(isNaN(d)) return;
    var clave=d.getFullYear()+"-"+d.getMonth()+"-"+d.getDate();
    serie.forEach(function(x){ if(x.clave===clave){ if(m.tipoMovimiento==="ENTRADA") x.e+=m.cantidad; if(m.tipoMovimiento==="SALIDA") x.s+=m.cantidad; } });
  });
  serie.forEach(function(x){ if(x.e>max)max=x.e; if(x.s>max)max=x.s; });
  html += '<section><h2>Entradas y salidas · 7 dias</h2><div class="bar">';
  serie.forEach(function(x){
    html += '<div class="d"><div style="display:flex;gap:2px;align-items:flex-end;height:90px;width:100%;justify-content:center"><i class="e" style="height:'+(x.e/max*90+4)+'px"></i><i class="s" style="height:'+(x.s/max*90+4)+'px"></i></div><span class="muted">'+x.et+'</span></div>';
  });
  html += '</div></section>';
  var top={};
  movs.forEach(function(m){ if(m.tipoMovimiento!=="SALIDA") return; top[m.productoNombre]=(top[m.productoNombre]||0)+m.cantidad; });
  var topL=Object.keys(top).map(function(n){ return {n:n,u:top[n]}; }).sort(function(a,b){ return b.u-a.u; }).slice(0,5);
  html += '<section><h2>Lo que mas se vende</h2>';
  if (!topL.length) html += '<p class="muted">Aun no hay salidas.</p>';
  topL.forEach(function(t){ html += '<div class="item"><span>'+esc(t.n)+'</span><b>'+t.u+'</b></div>'; });
  html += '</section>';
  html += '<section><h2>Descargas Excel</h2>';
  html += '<h3 style="margin:8px 0 4px">Lista de productos</h3>';
  html += '<p class="muted">Un Excel con lo que hay ahora: cantidades, lo que te costo y a como lo vendes. Para mandarlo por WhatsApp, imprimirlo o abrirlo en el computador.</p>';
  html += '<div class="row"><button class="go" id="xlProd">Descargar productos (Excel)</button></div>';
  html += '<h3 style="margin:16px 0 4px">Historial de movimientos</h3>';
  html += '<p class="muted">Un Excel de lo que entro y salio. Tu eliges: todo, este mes, esta semana o fechas del calendario.</p>';
  html += '<div class="row"><button class="ghost" id="xlTodo">Todo</button><button class="ghost" id="xlMes">Este mes</button><button class="ghost" id="xlSem">Esta semana</button></div>';
  html += '<div class="row" style="margin-top:8px"><label>Desde<input type="date" id="xlDesde" value="'+esc(xlDesde)+'"></label><label>Hasta<input type="date" id="xlHasta" value="'+esc(xlHasta)+'"></label><button class="go" id="xlCal">Descargar esas fechas</button></div></section>';
  html += '<section><h2>Contar lo del estante</h2><p class="muted">Escribe lo que ves. Al cambiar una cantidad aparece Aplicar al lado. Si sales sin aplicar, la pagina te avisa.</p>';
  html += '<div class="wrap"><table><thead><tr><th>Producto</th><th class="n">En la app</th><th class="n">En el estante</th></tr></thead><tbody>';
  prods.forEach(function(p){
    var v = conteo[p.codigoRef]!=null ? conteo[p.codigoRef] : p.stockActual;
    var n = parseInt(String(v).replace(/\D/g,""),10);
    var diff = conteo[p.codigoRef]!=null && !isNaN(n) && n!==p.stockActual;
    html += '<tr><td><b>'+esc(p.nombre)+'</b><div class="muted">'+esc(p.codigoRef)+'</div></td><td class="n">'+p.stockActual+'</td><td class="n"><input data-cnt="'+esc(p.codigoRef)+'" type="text" inputmode="numeric" pattern="[0-9]*" value="'+esc(v)+'" style="width:80px;text-align:center">';
    if (diff) html += '<button class="go cnt-ok" data-cnt-ok="'+esc(p.codigoRef)+'">Aplicar</button>';
    html += '</td></tr>';
  });
  html += '</tbody></table></div></section>';
  return html;
}

function vistaAjustes(){
  var n = state.negocio||{};
  var html = '<section><h2>Tu negocio</h2>';
  html += '<label class="muted">Nombre<input id="negNombre" class="full" placeholder="Ej. Tienda Don Pedro" value="'+esc(n.nombre||"")+'"></label>';
  html += '<label class="muted">NIT (opcional)<input id="negNit" class="full" placeholder="900.000.000-0" value="'+esc(n.nit||"")+'"></label>';
  html += '<label class="muted">Direccion (opcional)<input id="negDir" class="full" placeholder="Barrio, calle..." value="'+esc(n.direccion||"")+'"></label>';
  html += '<button class="go" id="btnNeg">Guardar</button></section>';
  html += '<section><h2>Vender aunque la app diga 0</h2><p class="muted">Si el estante no esta al dia, la venta se registra igual y queda marcada para corregir despues.</p>';
  html += '<label><input type="checkbox" id="negNeg"'+(n.permitirStockNegativo?" checked":"")+'> Permitir venta sin stock</label></section>';
  html += '<section><p class="muted">Rapistock Pro en el computador. Hasta '+MAX_PC+' PCs a la vez. El dueño puede cerrarlos desde el celular.</p></section>';
  return html;
}

function vistaClientes(){
  var t = (cliQ||"").toLowerCase();
  var lista = (state.clientes||[]).filter(function(c){
    if (!t) return true;
    return (c.nombre||"").toLowerCase().indexOf(t)>=0 || String(c.telefono||"").indexOf(t)>=0 || String(c.nit||"").toLowerCase().indexOf(t)>=0;
  });
  var html = '<input id="cq" placeholder="Nombre, celular o cedula..." value="'+esc(cliQ)+'">';
  html += '<section><h2>Clientes · '+(state.clientes||[]).length+'</h2><p class="muted">Guardalos para saber a quien le vendiste. En Mover eliges mostrador o un cliente de esta lista.</p>';
  if (!lista.length) html += '<p class="muted">Todavia no hay clientes. Toca + Cliente.</p>';
  lista.forEach(function(c){
    var extra = [c.telefono, c.nit, c.direccion].filter(function(x){ return x; }).join(" · ");
    html += '<div class="item"><div style="flex:1"><b>'+esc(c.nombre)+'</b><div class="muted">'+(extra?esc(extra):"Sin datos extra")+'</div></div><button class="ghost" data-cliedit="'+esc(c.id)+'">Editar</button></div>';
  });
  html += '</section><button class="fab" id="btnCliAdd">+ Cliente</button>';
  return html;
}

function vistaFormCli(){
  var c = formCli==="__nuevo__" ? {nombre:"",telefono:"",nit:"",direccion:""} : ((state.clientes||[]).filter(function(x){ return String(x.id)===String(formCli); })[0]||{});
  var html = '<div class="mask" id="maskCli"><div class="sheet"><h2>'+(formCli==="__nuevo__"?"Nuevo cliente":"Editar cliente")+'</h2>';
  html += '<label class="muted">Nombre<input id="cNom" class="full" placeholder="Ej. Doña Rosa" value="'+esc(c.nombre||"")+'"></label>';
  html += '<label class="muted">Celular (opcional)<input id="cTel" class="full" value="'+esc(c.telefono||"")+'"></label>';
  html += '<label class="muted">Cedula o NIT (opcional)<input id="cNit" class="full" value="'+esc(c.nit||"")+'"></label>';
  html += '<label class="muted">Barrio o direccion (opcional)<input id="cDir" class="full" value="'+esc(c.direccion||"")+'"></label>';
  html += '<div class="row" style="margin-top:12px"><button class="go" id="cSave">Guardar</button><button class="ghost" id="cCancel">Cancelar</button>';
  if (formCli!=="__nuevo__") html += '<button class="danger" id="cDel">Quitar</button>';
  html += '</div></div></div>';
  return html;
}

function vistaForm(){
  var p = formRef==="__nuevo__" ? {nombre:"",categoria:"Mercado",unidad:"und",stockActual:"",stockMinimo:10,costo:"",precioVenta:"",proveedor:"",ubicacion:"",codigoRef:sigCodigo("Mercado")} : (prod(formRef)||{});
  var cats = catsTodas();
  var html = '<div class="mask" id="mask"><div class="sheet"><h2>'+(formRef==="__nuevo__"?"Nuevo producto":"Editar producto")+'</h2>';
  html += '<label class="muted">Nombre<input id="fNom" class="full" value="'+esc(p.nombre||"")+'"></label>';
  html += '<label class="muted">Categoria<select id="fCat" class="full">';
  cats.forEach(function(c){ html += '<option'+(c===p.categoria?" selected":"")+'>'+esc(c)+"</option>"; });
  html += '<option value="__nueva__">+ Agregar categoria</option></select></label>';
  html += '<label class="muted">Codigo (lo arma la pagina)<input id="fCod" class="full" value="'+esc(p.codigoRef||"")+'" readonly></label>';
  html += '<label class="muted">Unidad<select id="fUni" class="full">';
  UNID.forEach(function(u){ html += '<option'+(u===p.unidad?" selected":"")+'>'+u+"</option>"; });
  html += '</select></label><div class="grid2">';
  html += '<label class="muted">Cantidad actual<input id="fStk" type="text" inputmode="numeric" value="'+(p.stockActual===""?"":p.stockActual)+'" placeholder="0"></label>';
  html += '<label class="muted">Se agota a partir de<input id="fMin" type="text" inputmode="numeric" value="'+(p.stockMinimo===""?10:p.stockMinimo)+'" placeholder="10"></label>';
  html += '<label class="muted">Lo que me costo ($)<input id="fCos" type="text" inputmode="numeric" value="'+(p.costo===""?"":Math.round(p.costo||0))+'" placeholder="1800"></label>';
  html += '<label class="muted">A como lo vendo ($)<input id="fPre" type="text" inputmode="numeric" value="'+(p.precioVenta===""?"":Math.round(p.precioVenta||0))+'" placeholder="2500"></label></div>';
  html += '<label class="muted">Proveedor<input id="fProv" class="full" value="'+esc(p.proveedor||"")+'"></label>';
  html += '<label class="muted">Ubicacion del producto<input id="fUbi" class="full" value="'+esc(p.ubicacion||"")+'" placeholder="Estante / vitrina"></label>';
  html += '<div class="row" style="margin-top:12px"><button class="go" id="fSave">Guardar</button><button class="ghost" id="fCancel">Cancelar</button>';
  if (formRef!=="__nuevo__") html += '<button class="danger" id="fDel">Quitar</button>';
  html += '</div></div></div>';
  return html;
}

function render(){
  if (!state) return;
  var y = window.scrollY;
  var inner = "";
  if (tab==="bodega") inner = vistaBodega();
  else if (tab==="mover") inner = vistaMover();
  else if (tab==="clientes") inner = vistaClientes();
  else if (tab==="historial") inner = vistaHistorial();
  else if (tab==="tablero") inner = vistaTablero();
  else inner = vistaAjustes();
  if (formRef) inner += vistaForm();
  if (formCli) inner += vistaFormCli();
  app.innerHTML = shell(inner);
  wire();
  window.scrollTo(0, y);
}
function wire(){
  app.querySelectorAll("[data-tab]").forEach(function(b){ b.onclick=function(){
    var next=b.getAttribute("data-tab");
    if (!confirmarSalidaConteo(next)) return;
    tab=next; q=""; render(); window.scrollTo(0,0);
  }; });
  var qq = document.getElementById("q");
  if (qq) qq.oninput=function(){ q=qq.value; };
  if (qq) qq.onchange=function(){ render(); };
  app.querySelectorAll("[data-f]").forEach(function(b){ b.onclick=function(){ filtro=b.getAttribute("data-f"); render(); }; });
  var bn = document.getElementById("btnNuevo");
  if (bn) bn.onclick=function(){ formRef="__nuevo__"; dirty=true; render(); };
  app.querySelectorAll("[data-edit]").forEach(function(b){ b.onclick=function(){ formRef=b.getAttribute("data-edit"); dirty=true; render(); }; });
  var tIn=document.getElementById("tIn"); if(tIn) tIn.onclick=function(){ tipoMov="ENTRADA"; motivo=MOT_IN[0]; carrito={}; clienteVenta=null; render(); };
  var tOut=document.getElementById("tOut"); if(tOut) tOut.onclick=function(){ tipoMov="SALIDA"; motivo=MOT_OUT[0]; carrito={}; render(); };
  var mot=document.getElementById("motivo"); if(mot) mot.onchange=function(){ motivo=mot.value; };
  var rf=document.getElementById("refmov"); if(rf) rf.oninput=function(){ referencia=rf.value; };
  var cs=document.getElementById("cliSel");
  if (cs) cs.onchange=function(){
    var id = cs.value;
    if (!id){ clienteVenta=null; return; }
    var hit = (state.clientes||[]).filter(function(c){ return String(c.id)===String(id); })[0];
    clienteVenta = hit || null;
  };
  var bcn=document.getElementById("btnCliNuevo");
  if (bcn) bcn.onclick=function(){ formCli="__nuevo__"; dirty=true; render(); };
  var bca=document.getElementById("btnCliAdd");
  if (bca) bca.onclick=function(){ formCli="__nuevo__"; dirty=true; render(); };
  var cq=document.getElementById("cq");
  if (cq){ cq.oninput=function(){ cliQ=cq.value; }; cq.onchange=function(){ render(); }; }
  app.querySelectorAll("[data-cliedit]").forEach(function(b){ b.onclick=function(){ formCli=b.getAttribute("data-cliedit"); dirty=true; render(); }; });
  var cc=document.getElementById("cCancel"); if(cc) cc.onclick=function(){ formCli=null; dirty=false; render(); };
  var maskc=document.getElementById("maskCli"); if(maskc) maskc.onclick=function(e){ if(e.target===maskc){ formCli=null; dirty=false; render(); } };
  var csv=document.getElementById("cSave");
  if (csv) csv.onclick=function(){
    var nom=(document.getElementById("cNom").value||"").trim();
    if (!nom){ aviso("Escribe el nombre", true); return; }
    var tel=(document.getElementById("cTel").value||"").trim();
    var nit=(document.getElementById("cNit").value||"").trim();
    var dir=(document.getElementById("cDir").value||"").trim();
    state.clientes = state.clientes||[];
    if (formCli==="__nuevo__"){
      var nuevo = {id: Date.now(), nombre:nom, telefono:tel, nit:nit, direccion:dir};
      state.clientes.push(nuevo);
      if (tipoMov==="SALIDA") clienteVenta = nuevo;
    } else {
      state.clientes = state.clientes.map(function(c){
        if (String(c.id)!==String(formCli)) return c;
        return {id:c.id, nombre:nom, telefono:tel, nit:nit, direccion:dir};
      });
      if (clienteVenta && String(clienteVenta.id)===String(formCli)) clienteVenta = {id:clienteVenta.id, nombre:nom, telefono:tel, nit:nit, direccion:dir};
    }
    formCli=null; dirty=false;
    save().then(function(){ aviso("Cliente guardado"); render(); }).catch(function(){ aviso("No pude guardar", true); });
  };
  var cd=document.getElementById("cDel");
  if (cd) cd.onclick=function(){
    if (!confirm("¿Quitar este cliente? Las ventas ya hechas se conservan.")) return;
    state.clientes = (state.clientes||[]).filter(function(c){ return String(c.id)!==String(formCli); });
    if (clienteVenta && String(clienteVenta.id)===String(formCli)) clienteVenta=null;
    formCli=null; dirty=false;
    save().then(function(){ aviso("Cliente quitado"); render(); });
  };
  app.querySelectorAll("[data-plus]").forEach(function(b){ b.onclick=function(){
    var ref=b.getAttribute("data-plus"); var p=prod(ref); if(!p) return;
    var c=carrito[ref]||{cant:0,costo:p.costo||0};
    var next=c.cant+1;
    if (tipoMov==="SALIDA" && next>p.stockActual && !(state.negocio&&state.negocio.permitirStockNegativo)){ aviso("No hay suficiente cantidad para sacar", true); return; }
    c.cant=next; carrito[ref]=c; render();
  }; });
  app.querySelectorAll("[data-minus]").forEach(function(b){ b.onclick=function(){
    var ref=b.getAttribute("data-minus"); if(!carrito[ref]) return;
    carrito[ref].cant--; if(carrito[ref].cant<=0) delete carrito[ref]; render();
  }; });
  app.querySelectorAll("[data-qty]").forEach(function(b){ b.onclick=function(){
    var ref=b.getAttribute("data-qty");
    var p=prod(ref); if(!p) return;
    var cur=carrito[ref] ? carrito[ref].cant : 0;
    var inp=document.createElement("input");
    inp.type="text";
    inp.setAttribute("inputmode","numeric");
    inp.setAttribute("pattern","[0-9]*");
    inp.autocomplete="off";
    inp.value = cur>0 ? String(cur) : "";
    inp.style.width="72px";
    inp.style.textAlign="center";
    inp.style.fontWeight="800";
    b.replaceWith(inp); inp.focus(); inp.select();
    dirty = true;
    var done=false;
    function apply(){
      if (done) return;
      done=true;
      dirty=false;
      var raw=String(inp.value||"").replace(/\D/g,"");
      var n=parseInt(raw,10);
      if (!raw || isNaN(n) || n<=0){ delete carrito[ref]; render(); return; }
      if (tipoMov==="SALIDA" && n>p.stockActual && !(state.negocio&&state.negocio.permitirStockNegativo)){
        aviso("No hay suficiente cantidad para sacar", true); render(); return;
      }
      carrito[ref]={cant:n, costo:p.costo||0}; render();
    }
    inp.addEventListener("wheel", function(e){ e.preventDefault(); });
    inp.onkeydown=function(e){ if(e.key==="Enter"){ e.preventDefault(); apply(); } };
    inp.onblur=apply;
  }; });
  var br=document.getElementById("btnReg"); if(br) br.onclick=registrarCarrito;
  var hq=document.getElementById("hq"); if(hq){ hq.oninput=function(){ histQ=hq.value; }; hq.onchange=function(){ render(); }; }
  app.querySelectorAll("[data-ht]").forEach(function(b){ b.onclick=function(){ histTipo=b.getAttribute("data-ht"); render(); }; });
  var xp=document.getElementById("xlProd"); if(xp) xp.onclick=excelProductos;
  var xt=document.getElementById("xlTodo"); if(xt) xt.onclick=function(){ excelHistorial(null,null,"todo"); };
  var xm=document.getElementById("xlMes"); if(xm) xm.onclick=function(){ var n=new Date(); excelHistorial(new Date(n.getFullYear(),n.getMonth(),1), new Date(n.getFullYear(),n.getMonth()+1,0,23,59,59), "mes"); };
  var xs=document.getElementById("xlSem"); if(xs) xs.onclick=function(){ var n=new Date(); var lunes=new Date(n); lunes.setDate(n.getDate()-(n.getDay()||7)+1); lunes.setHours(0,0,0,0); var dom=new Date(lunes); dom.setDate(lunes.getDate()+6); dom.setHours(23,59,59,0); excelHistorial(lunes,dom,"semana"); };
  var xc=document.getElementById("xlCal");
  var xd=document.getElementById("xlDesde"); if (xd) xd.oninput=function(){ xlDesde=xd.value; };
  var xh=document.getElementById("xlHasta"); if (xh) xh.oninput=function(){ xlHasta=xh.value; };
  if (xc) xc.onclick=function(){
    xlDesde=(document.getElementById("xlDesde").value||"");
    xlHasta=(document.getElementById("xlHasta").value||"");
    if (!xlDesde || !xlHasta){ aviso("Elige las dos fechas", true); return; }
    var desde=new Date(xlDesde+"T00:00:00");
    var hasta=new Date(xlHasta+"T23:59:59");
    if (hasta<desde){ aviso("La fecha final debe ser despues de la inicial", true); return; }
    excelHistorial(desde, hasta, "fechas");
  };
    app.querySelectorAll("[data-hr]").forEach(function(b){ b.onclick=function(){ histRango=b.getAttribute("data-hr"); render(); }; });
  var hcli=document.getElementById("hCli"); if(hcli) hcli.onchange=function(){ histCli=hcli.value; render(); };
  var hprod=document.getElementById("hProd"); if(hprod) hprod.onchange=function(){ histProd=hprod.value; render(); };
  var hd=document.getElementById("hDesde"); if(hd) hd.oninput=function(){ histDesde=hd.value; };
  var hh=document.getElementById("hHasta"); if(hh) hh.oninput=function(){ histHasta=hh.value; render(); };
  var bl=document.getElementById("btnLimpiar");
  if (bl) bl.onclick=function(){
    if (!confirm("Se descarga un Excel con TODO el historial y despues se vacia el listado. Las barras de 7 dias del Tablero quedan en cero. La bodega no se toca. ¿Seguimos?")) return;
    var ok = excelHistorial(null,null,"todo");
    if (ok===false) return;
    state.movimientos = [];
    state.historialReset = Date.now();
    save().then(function(){ aviso("Historial limpio. El Excel de respaldo ya se descargo."); tab="historial"; render(); });
  };
    app.querySelectorAll("[data-cnt]").forEach(function(inp){
    inp.oninput=function(){
      var ref=inp.getAttribute("data-cnt");
      conteo[ref]=inp.value;
      var p=prod(ref);
      var n=parseInt(String(inp.value||"").replace(/\D/g,""),10);
      var dirty = p && !isNaN(n) && n!==p.stockActual;
      var td=inp.parentNode;
      var btn=td.querySelector("[data-cnt-ok]");
      if (dirty){
        if (!btn){
          btn=document.createElement("button");
          btn.className="go cnt-ok";
          btn.setAttribute("data-cnt-ok", ref);
          btn.textContent="Aplicar";
          btn.onclick=function(){ aplicarConteo(ref); };
          td.appendChild(btn);
        }
      } else if (btn){
        btn.remove();
      }
    };
    inp.addEventListener("wheel", function(e){ e.preventDefault(); });
  });
  app.querySelectorAll("[data-cnt-ok]").forEach(function(b){
    b.onclick=function(){ aplicarConteo(b.getAttribute("data-cnt-ok")); };
  });
  var bc=document.getElementById("btnConteo"); if(bc) bc.onclick=function(){ aplicarConteo(); };
  var bn2=document.getElementById("btnNeg");
  if (bn2) bn2.onclick=function(){
    state.negocio = state.negocio||{};
    state.negocio.nombre = (document.getElementById("negNombre").value||"").trim();
    state.negocio.nit = (document.getElementById("negNit").value||"").trim();
    state.negocio.direccion = (document.getElementById("negDir").value||"").trim();
    save().then(function(){ aviso("Datos del negocio guardados"); render(); });
  };
  var ng=document.getElementById("negNeg");
  if (ng) ng.onchange=function(){ state.negocio=state.negocio||{}; state.negocio.permitirStockNegativo=ng.checked; save().then(function(){ aviso("Listo"); }); };
  var fc=document.getElementById("fCancel"); if(fc) fc.onclick=function(){ formRef=null; dirty=false; render(); };
  var mask=document.getElementById("mask"); if(mask) mask.onclick=function(e){ if(e.target===mask){ formRef=null; dirty=false; render(); } };
  var fcat=document.getElementById("fCat");
  if (fcat) fcat.onchange=function(){
    if (fcat.value==="__nueva__"){
      var nom=prompt("Nombre de la categoria nueva:");
      if (!nom){ fcat.value="Mercado"; return; }
      state.categoriasExtra=state.categoriasExtra||{};
      state.categoriasExtra[nom.trim()]=genPref(nom.trim());
      if (formRef==="__nuevo__") document.getElementById("fCod").value=sigCodigo(nom.trim());
      var opt=document.createElement("option"); opt.text=nom.trim(); opt.selected=true;
      fcat.insertBefore(opt, fcat.lastChild);
      return;
    }
    if (formRef==="__nuevo__") document.getElementById("fCod").value=sigCodigo(fcat.value);
  };
  var fs=document.getElementById("fSave");
  if (fs) fs.onclick=function(){
    var esNuevo = formRef==="__nuevo__";
    var p = esNuevo ? {} : Object.assign({}, prod(formRef)||{});
    p.nombre=(document.getElementById("fNom").value||"").trim();
    p.categoria=document.getElementById("fCat").value;
    p.codigoRef=document.getElementById("fCod").value;
    p.unidad=document.getElementById("fUni").value;
    p.stockActual=parseInt(String(document.getElementById("fStk").value||"").replace(/\D/g,""),10)||0;
    p.stockMinimo=parseInt(String(document.getElementById("fMin").value||"").replace(/\D/g,""),10); if(isNaN(p.stockMinimo)) p.stockMinimo=10;
    p.costo=parseFloat(String(document.getElementById("fCos").value||"").replace(/[^\d.,]/g,"").replace(",","."))||0;
    p.precioVenta=parseFloat(String(document.getElementById("fPre").value||"").replace(/[^\d.,]/g,"").replace(",","."))||0;
    p.proveedor=(document.getElementById("fProv").value||"").trim();
    p.ubicacion=(document.getElementById("fUbi").value||"").trim();
    guardarProducto(p, esNuevo);
  };
  var fd=document.getElementById("fDel"); if(fd) fd.onclick=function(){ quitarProducto(formRef); formRef=null; dirty=false; };
}

load();
setInterval(load, 8000);