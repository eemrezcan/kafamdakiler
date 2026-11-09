/// The payload of a notification that came from the server (FCM) starts with this; the rest is the in-app route to open.
const sunucuBildirimOneki = 'rota:';

/// The Bugün screen: where a tap goes when the notification names no (valid) target.
const _varsayilanRota = '/';

/// The in-app route a notification points at. [rota] is what the server stored (null: Bugün); a `{id}` in it is replaced
/// by [kimlik]. Anything that is not a plain in-app path (an address, a path with `..`, a `{id}` left unfilled) is
/// ignored: the server's text must never send the app somewhere it did not mean to go.
String hedefRotasi(String? rota, String? kimlik) {
  if (rota == null) return _varsayilanRota;
  final r = rota.trim();
  if (!r.startsWith('/') || r.startsWith('//') || r.contains('://') || r.contains('..') || r.contains('?') || r.contains('#')) {
    return _varsayilanRota;
  }
  if (!r.contains('{id}')) return r;
  if (kimlik == null || kimlik.isEmpty) return _varsayilanRota;
  return r.replaceAll('{id}', Uri.encodeComponent(kimlik));
}

/// The payload to put on the local notification of a server notification.
String sunucuBildirimYuku(String? rota, String? kimlik) => '$sunucuBildirimOneki${hedefRotasi(rota, kimlik)}';

/// The route inside a payload made by [sunucuBildirimYuku]; null for any other payload.
String? sunucuBildirimRotasi(String? yuk) =>
    yuk != null && yuk.startsWith(sunucuBildirimOneki) ? yuk.substring(sunucuBildirimOneki.length) : null;
