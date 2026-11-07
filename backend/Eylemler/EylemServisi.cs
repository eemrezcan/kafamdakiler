using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Eylemler;

public enum EylemSonucuTuru
{
    Tamam,
    // The suggestion was dropped because its kind is Yasak. Nothing was stored but a log line.
    Atlandi,
    Bulunamadi,
    Gecersiz,
    Catisma,
    // The action was tried and failed. The Eylem is kept as Hatali.
    Hata,
}

public record EylemSonucu(EylemSonucuTuru Tur, Eylem? Eylem = null, string? Alan = null, string? Mesaj = null)
{
    public bool Basarili => Tur == EylemSonucuTuru.Tamam;
}

// The rules of the approval queue and the permission modes (K2.6). The endpoints call these; the modules that suggest
// actions (inbox, voice, briefing...) call OnerAsync. Nothing else creates an Eylem or applies one.
public class EylemServisi(AppDbContext db, EylemTurleri turler, TimeProvider saat, ILogger<EylemServisi> gunluk)
{
    // So many rejections of a kind in a row take KendinYap back to Sor.
    public const int ArdArdaRedSiniri = 3;

    // The list endpoint never returns more than this.
    public const int ListeSiniri = 200;

    // A suggestion arrives. The order of the checks is the safety rule: Yasak, then outside source, then KendinYap, else Sor.
    public async Task<EylemSonucu> OnerAsync(EylemOnerisi oneri, CancellationToken ct)
    {
        if (turler.Bul(oneri.Tur) is not { } tur)
            return Gecersiz("tur", "Bilinmeyen eylem türü.");
        if (string.IsNullOrWhiteSpace(oneri.Ozet) || oneri.Ozet.Length > 200)
            return Gecersiz("ozet", "Özet zorunlu ve en çok 200 karakter olabilir.");
        if (string.IsNullOrWhiteSpace(oneri.Kaynak) || oneri.Kaynak.Length > 30)
            return Gecersiz("kaynak", "Kaynak zorunlu ve en çok 30 karakter olabilir.");
        if (oneri.Gerekce is { Length: > 1000 })
            return Gecersiz("gerekce", "Gerekçe en çok 1000 karakter olabilir.");
        if (oneri.Guven is < 0 or > 1)
            return Gecersiz("guven", "Güven 0 ile 1 arasında olmalı.");

        var simdi = saat.GetUtcNow();
        var izin = await db.EylemIzinleri.FindAsync([tur.Ad], ct);
        var kip = izin?.Kip ?? EylemKipi.Sor;

        if (kip == EylemKipi.Yasak)
        {
            Gunluk(null, tur.Ad, EylemOlayi.YasakAtlandi, $"Yasak olduğu için atlandı: {oneri.Ozet}", null, simdi);
            await db.SaveChangesAsync(ct);
            return new EylemSonucu(EylemSonucuTuru.Atlandi, Mesaj: "Bu tür yasak olduğu için öneri kaydedilmedi.");
        }

        var dogrulama = await tur.DogrulaAsync(oneri.Yuk, ct);
        if (!dogrulama.Basarili)
            return new EylemSonucu(EylemSonucuTuru.Gecersiz, Alan: dogrulama.Alan, Mesaj: dogrulama.Mesaj);

        var eylem = new Eylem
        {
            Tur = tur.Ad,
            Yuk = oneri.Yuk.GetRawText(),
            Ozet = oneri.Ozet.Trim(),
            Kaynak = oneri.Kaynak.Trim(),
            DisKaynak = oneri.DisKaynak,
            Gerekce = string.IsNullOrWhiteSpace(oneri.Gerekce) ? null : oneri.Gerekce.Trim(),
            Guven = oneri.Guven,
            CreatedAt = simdi,
        };
        db.Eylemler.Add(eylem);
        Gunluk(eylem.Id, tur.Ad, EylemOlayi.Onerildi, $"Öneri geldi ({eylem.Kaynak}): {eylem.Ozet}", null, simdi);
        // Stored as Bekliyor first: if applying it fails, the suggestion and its log line are still there.
        await db.SaveChangesAsync(ct);

        // A kind that cannot be undone is never applied by itself: "Kendin yap" promises an undo.
        if (kip == EylemKipi.KendinYap && !eylem.DisKaynak && tur.GeriAlinabilir)
            return await EtkiyiUygulaAsync(eylem, tur, null, otomatik: true, ct);

        return Tamam(eylem);
    }

    public async Task<EylemSonucu> UygulaAsync(Guid id, JsonElement? duzeltilmisYuk, Guid? kullanici, CancellationToken ct)
    {
        var eylem = await db.Eylemler.FindAsync([id], ct);
        if (eylem is null)
            return new EylemSonucu(EylemSonucuTuru.Bulunamadi);
        if (eylem.Durum != EylemDurumu.Bekliyor)
            return Catisma($"Eylem '{DurumAdi(eylem.Durum)}' durumunda; yalnız bekleyen eylem uygulanabilir.");
        if (turler.Bul(eylem.Tur) is not { } tur)
            return Catisma("Bu eylem türü artık tanınmıyor.");

        // A corrected payload is checked like a new suggestion; so is the stored one (the rules may have changed).
        using var kayitli = JsonDocument.Parse(eylem.Yuk);
        var yuk = duzeltilmisYuk ?? kayitli.RootElement;
        var dogrulama = await tur.DogrulaAsync(yuk, ct);
        if (!dogrulama.Basarili)
            return new EylemSonucu(EylemSonucuTuru.Gecersiz, Alan: dogrulama.Alan, Mesaj: dogrulama.Mesaj);

        if (duzeltilmisYuk is { } duzeltilmis)
            eylem.Yuk = duzeltilmis.GetRawText();

        // An approval ends a run of rejections.
        if (await db.EylemIzinleri.FindAsync([tur.Ad], ct) is { } izin)
            izin.ArdArdaRed = 0;

        return await EtkiyiUygulaAsync(eylem, tur, kullanici, otomatik: false, ct);
    }

    public async Task<EylemSonucu> ReddetAsync(Guid id, bool birDahaOnerme, Guid? kullanici, CancellationToken ct)
    {
        var eylem = await db.Eylemler.FindAsync([id], ct);
        if (eylem is null)
            return new EylemSonucu(EylemSonucuTuru.Bulunamadi);
        if (eylem.Durum != EylemDurumu.Bekliyor)
            return Catisma($"Eylem '{DurumAdi(eylem.Durum)}' durumunda; yalnız bekleyen eylem reddedilebilir.");

        var simdi = saat.GetUtcNow();
        eylem.Durum = EylemDurumu.Reddedildi;
        eylem.KararAni = simdi;
        eylem.KararVerenId = kullanici;
        Gunluk(eylem.Id, eylem.Tur, EylemOlayi.Reddedildi, birDahaOnerme ? $"Reddedildi, bir daha önerme: {eylem.Ozet}" : $"Reddedildi: {eylem.Ozet}", kullanici, simdi);

        var izin = await IzinAsync(eylem.Tur, ct);
        izin.ArdArdaRed++;
        izin.GuncellemeAni = simdi;
        if (birDahaOnerme)
        {
            if (izin.Kip != EylemKipi.Yasak)
                KipDegistir(izin, EylemKipi.Yasak, "bir daha önerme seçildi", kullanici, simdi);
        }
        else if (izin.Kip == EylemKipi.KendinYap && izin.ArdArdaRed >= ArdArdaRedSiniri)
        {
            KipDegistir(izin, EylemKipi.Sor, $"art arda {ArdArdaRedSiniri} red", null, simdi);
        }

        return await KaydetAsync(eylem, ct);
    }

    public async Task<EylemSonucu> GeriAlAsync(Guid id, Guid? kullanici, CancellationToken ct)
    {
        var eylem = await db.Eylemler.FindAsync([id], ct);
        if (eylem is null)
            return new EylemSonucu(EylemSonucuTuru.Bulunamadi);
        if (eylem.Durum != EylemDurumu.Uygulandi)
            return Catisma($"Eylem '{DurumAdi(eylem.Durum)}' durumunda; yalnız uygulanmış eylem geri alınabilir.");
        if (turler.Bul(eylem.Tur) is not { } tur)
            return Catisma("Bu eylem türü artık tanınmıyor.");
        if (!tur.GeriAlinabilir)
            return Catisma("Bu türdeki eylem geri alınamaz.");

        var simdi = saat.GetUtcNow();
        try
        {
            using var bilgi = JsonDocument.Parse(eylem.GeriAlmaBilgisi ?? "null");
            await tur.GeriAlAsync(bilgi.RootElement, new EylemBaglami(db, simdi), ct);
            eylem.Durum = EylemDurumu.GeriAlindi;
            eylem.GeriAlmaAni = simdi;
            Gunluk(eylem.Id, eylem.Tur, EylemOlayi.GeriAlindi, $"Geri alındı: {eylem.Ozet}", kullanici, simdi);
            return await KaydetAsync(eylem, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogError(e, "Undoing action {EylemId} failed", eylem.Id);
            db.ChangeTracker.Clear();
            return new EylemSonucu(EylemSonucuTuru.Hata, Mesaj: "Eylem geri alınamadı.");
        }
    }

    // Pending by default (newest first); any other status is sorted by when it was decided.
    public async Task<List<Eylem>> ListeAsync(EylemDurumu durum, CancellationToken ct) =>
        await db.Eylemler.AsNoTracking().Where(e => e.Durum == durum)
            .OrderByDescending(e => e.KararAni ?? e.CreatedAt).ThenByDescending(e => e.Id)
            .Take(ListeSiniri).ToListAsync(ct);

    // For the badge in the menu.
    public async Task<int> BekleyenSayisiAsync(CancellationToken ct) =>
        await db.Eylemler.CountAsync(e => e.Durum == EylemDurumu.Bekliyor, ct);

    public async Task<Eylem?> GetirAsync(Guid id, CancellationToken ct) =>
        await db.Eylemler.AsNoTracking().FirstOrDefaultAsync(e => e.Id == id, ct);

    // Every registered kind with its mode; a kind without a row is Sor.
    public async Task<List<EylemKipiDto>> KipleriGetirAsync(CancellationToken ct)
    {
        var satirlar = await db.EylemIzinleri.AsNoTracking().ToDictionaryAsync(i => i.Tur, ct);
        return turler.Tumu.OrderBy(t => t.GorunenAd)
            .Select(t => satirlar.GetValueOrDefault(t.Ad) is { } i
                ? new EylemKipiDto(t.Ad, t.GorunenAd, i.Kip, i.ArdArdaRed)
                : new EylemKipiDto(t.Ad, t.GorunenAd, EylemKipi.Sor, 0))
            .ToList();
    }

    // Null when no such kind is registered. Choosing a mode also clears the run of rejections.
    public async Task<EylemKipiDto?> KipAyarlaAsync(string turAdi, EylemKipi kip, Guid? kullanici, CancellationToken ct)
    {
        if (turler.Bul(turAdi) is not { } tur)
            return null;

        var simdi = saat.GetUtcNow();
        var izin = await IzinAsync(tur.Ad, ct);
        izin.ArdArdaRed = 0;
        izin.GuncellemeAni = simdi;
        if (izin.Kip != kip)
            KipDegistir(izin, kip, "yönetimden ayarlandı", kullanici, simdi);

        await db.SaveChangesAsync(ct);
        return new EylemKipiDto(tur.Ad, tur.GorunenAd, izin.Kip, izin.ArdArdaRed);
    }

    public EylemDto DtoYap(Eylem e)
    {
        using var yuk = JsonDocument.Parse(e.Yuk);
        JsonElement? geriAlma = null;
        if (e.GeriAlmaBilgisi is not null)
        {
            using var bilgi = JsonDocument.Parse(e.GeriAlmaBilgisi);
            geriAlma = bilgi.RootElement.Clone();
        }

        return new EylemDto(
            e.Id, e.Tur, turler.Bul(e.Tur)?.GorunenAd ?? e.Tur, yuk.RootElement.Clone(), e.Ozet, e.Kaynak, e.DisKaynak, e.Gerekce, e.Guven,
            e.Durum, geriAlma, e.HataMesaji, e.CreatedAt, e.KararAni, e.UygulamaAni, e.GeriAlmaAni, e.KararVerenId,
            turler.Bul(e.Tur)?.GeriAlinabilir ?? true);
    }

    // The effect and the status change are saved together. If the effect throws, nothing of it is kept and the action
    // becomes Hatali, so a person sees it failed instead of it staying in the queue for ever.
    private async Task<EylemSonucu> EtkiyiUygulaAsync(Eylem eylem, IEylemTuru tur, Guid? kullanici, bool otomatik, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        try
        {
            using var yuk = JsonDocument.Parse(eylem.Yuk);
            var bilgi = await tur.UygulaAsync(yuk.RootElement, new EylemBaglami(db, simdi), ct);
            eylem.Durum = EylemDurumu.Uygulandi;
            eylem.GeriAlmaBilgisi = bilgi.GetRawText();
            eylem.KararAni = simdi;
            eylem.UygulamaAni = simdi;
            eylem.KararVerenId = kullanici;
            Gunluk(eylem.Id, eylem.Tur, otomatik ? EylemOlayi.OtomatikUygulandi : EylemOlayi.Uygulandi,
                otomatik ? $"Kendiliğinden uygulandı: {eylem.Ozet}" : $"Uygulandı: {eylem.Ozet}", kullanici, simdi);
            await db.SaveChangesAsync(ct);
            return Tamam(eylem);
        }
        catch (DbUpdateConcurrencyException)
        {
            db.ChangeTracker.Clear();
            return Catisma("Eylem aynı anda başka bir istekle değiştirildi.");
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogError(e, "Applying action {EylemId} ({Tur}) failed", eylem.Id, eylem.Tur);
            db.ChangeTracker.Clear();

            var hatali = await db.Eylemler.FindAsync([eylem.Id], ct);
            if (hatali is null)
                return new EylemSonucu(EylemSonucuTuru.Hata, Mesaj: "Eylem uygulanamadı.");
            // An effect outside the database (the brain) can fail on the second of two approvals at once while the first one went through.
            if (hatali.Durum != EylemDurumu.Bekliyor)
                return Catisma("Eylem aynı anda başka bir istekle değiştirildi.");

            hatali.Durum = EylemDurumu.Hatali;
            hatali.HataMesaji = "Uygulanırken beklenmeyen bir hata oluştu.";
            hatali.KararAni = simdi;
            hatali.KararVerenId = kullanici;
            Gunluk(hatali.Id, hatali.Tur, EylemOlayi.Hatali, $"Uygulanamadı: {hatali.Ozet}", kullanici, simdi);
            await db.SaveChangesAsync(ct);
            return new EylemSonucu(EylemSonucuTuru.Hata, hatali, Mesaj: "Eylem uygulanamadı.");
        }
    }

    private async Task<EylemSonucu> KaydetAsync(Eylem eylem, CancellationToken ct)
    {
        try
        {
            await db.SaveChangesAsync(ct);
            return Tamam(eylem);
        }
        catch (DbUpdateConcurrencyException)
        {
            db.ChangeTracker.Clear();
            return Catisma("Eylem aynı anda başka bir istekle değiştirildi.");
        }
    }

    // The mode row of a kind, created as Sor on first use.
    private async Task<EylemIzni> IzinAsync(string tur, CancellationToken ct)
    {
        if (await db.EylemIzinleri.FindAsync([tur], ct) is { } mevcut)
            return mevcut;

        var yeni = new EylemIzni { Tur = tur };
        db.EylemIzinleri.Add(yeni);
        return yeni;
    }

    private void KipDegistir(EylemIzni izin, EylemKipi yeni, string neden, Guid? kullanici, DateTimeOffset simdi)
    {
        Gunluk(null, izin.Tur, EylemOlayi.KipDegisti, $"Kip {izin.Kip} → {yeni} ({neden}).", kullanici, simdi);
        izin.Kip = yeni;
        // Choosing or losing a mode starts the count again.
        izin.ArdArdaRed = 0;
    }

    private void Gunluk(Guid? eylemId, string tur, EylemOlayi olay, string aciklama, Guid? kullanici, DateTimeOffset zaman) =>
        db.EylemGunlukleri.Add(new EylemGunlugu { EylemId = eylemId, Tur = tur, Olay = olay, Aciklama = aciklama, KullaniciId = kullanici, Zaman = zaman });

    private static EylemSonucu Tamam(Eylem eylem) => new(EylemSonucuTuru.Tamam, eylem);

    private static EylemSonucu Gecersiz(string alan, string mesaj) => new(EylemSonucuTuru.Gecersiz, Alan: alan, Mesaj: mesaj);

    private static EylemSonucu Catisma(string mesaj) => new(EylemSonucuTuru.Catisma, Mesaj: mesaj);

    private static string DurumAdi(EylemDurumu durum) => durum switch
    {
        EylemDurumu.Bekliyor => "bekliyor",
        EylemDurumu.Uygulandi => "uygulandı",
        EylemDurumu.Reddedildi => "reddedildi",
        EylemDurumu.GeriAlindi => "geri alındı",
        _ => "hatalı",
    };
}
