// The repository card of a project (K2.5, `GET /api/beyin/projeler/{kimlik}/repo`). Plain hand-written JSON (camelCase,
// like the API); nothing here needs code generation.

/// `RepoCommitDto`: one commit. [hash] is the short hash, [mesaj] the first line of the message.
class RepoCommit {
  const RepoCommit({required this.hash, required this.mesaj, this.yazar, this.tarih});

  final String hash;
  final String mesaj;
  final String? yazar;
  final DateTime? tarih;

  factory RepoCommit.fromJson(Map<String, dynamic> json) => RepoCommit(
        hash: json['hash'] as String,
        mesaj: json['mesaj'] as String,
        yazar: json['yazar'] as String?,
        tarih: json['tarih'] == null ? null : DateTime.parse(json['tarih'] as String),
      );
}

/// `ProjeRepoOzetiDto`. [durum] is `tamam`, `tokenYok` (only the link is shown), `depoYok`, `oranSiniri`, `yetkiYok` or
/// `hata`; [commitler] and [acikPrSayisi] are set only for `tamam`. [mesaj] says why when it is not `tamam`.
class ProjeRepoOzeti {
  const ProjeRepoOzeti({
    required this.proje,
    required this.depo,
    required this.baglanti,
    required this.durum,
    this.mesaj,
    this.commitler,
    this.acikPrSayisi,
  });

  final String proje;
  final String depo;
  final String baglanti;
  final String durum;
  final String? mesaj;
  final List<RepoCommit>? commitler;
  final int? acikPrSayisi;

  bool get tamam => durum == 'tamam';

  factory ProjeRepoOzeti.fromJson(Map<String, dynamic> json) => ProjeRepoOzeti(
        proje: json['proje'] as String,
        depo: json['depo'] as String,
        baglanti: json['baglanti'] as String,
        durum: json['durum'] as String,
        mesaj: json['mesaj'] as String?,
        commitler: json['commitler'] == null
            ? null
            : [for (final c in json['commitler'] as List<dynamic>) RepoCommit.fromJson(c as Map<String, dynamic>)],
        acikPrSayisi: json['acikPrSayisi'] as int?,
      );
}
