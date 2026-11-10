using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The work cards against the real beyin.py and a throwaway copy of ornek-beyin/ (the template is never written to). Skipped when
// beyin.py is not on this machine (TestAyari.GercekBeyin). The VPS side of the story (the plan, the questions, moving the card on) is
// told with the brain's own commands, as the plan session would; the phone side goes through IsKartlari, as the API does. What the
// fake brain answers is only as good as what is read off the real one here: the shapes, the stages, the gate approval, the refusals.
public sealed class GercekBeyinIsTests : IDisposable
{
    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-is-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_vault))
            Directory.Delete(_vault, recursive: true);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private BeyinIstemcisi Hazirla()
    {
        var ayar = TestAyari.GercekBeyin(_vault);
        Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));
        return new BeyinIstemcisi(ayar);
    }

    // The VPS writes with its own name; the phone's name is always `kullanici`.
    private static async Task Vps(BeyinIstemcisi beyin, string[] komut, params string[] konumsal)
    {
        var sonuc = await beyin.CalistirAsync(komut.Append("--kim=vps"), Ct, konumsal);
        Assert.True(sonuc.Basarili, $"{string.Join(' ', komut)} {string.Join(' ', konumsal)}: {sonuc.Mesaj}");
    }

    private static async Task VpsPlan(BeyinIstemcisi beyin, string kimlik, string plan)
    {
        var dosya = Path.Combine(Path.GetTempPath(), "kd-plan-" + Guid.NewGuid().ToString("N") + ".md");
        try
        {
            await File.WriteAllTextAsync(dosya, plan, Ct);
            await Vps(beyin, ["is", "plan", $"--metin-dosya={dosya}"], kimlik);
        }
        finally
        {
            File.Delete(dosya);
        }
    }

    private static IsKartiDto Kart(YazmaYaniti yanit)
    {
        Assert.True(yanit.Basarili, $"{yanit.Durum} {yanit.Baslik} {yanit.Ayrinti}");
        return Assert.IsType<IsKartiDto>(yanit.Veri);
    }

    private static async Task<IsAyrintiDto> Ayrinti(BeyinIstemcisi beyin, string kimlik)
    {
        var yanit = await IsKartlari.Al(kimlik, beyin, Gunluk, Ct);
        Assert.True(yanit.Basarili, $"{yanit.Durum} {yanit.Baslik} {yanit.Ayrinti}");
        return yanit.Veri!;
    }

    private static Task<YazmaYaniti> Asama(BeyinIstemcisi beyin, string kimlik, string asama, string? gerekce = null) =>
        IsKartlari.AsamaDegistir(kimlik, new(asama, gerekce, null), beyin, Gunluk, TimeProvider.System, Ct);

    private static async Task<List<IsKartiDto>> Liste(BeyinIstemcisi beyin, string? asama = null, string? proje = null, bool kapali = false)
    {
        var yanit = await IsKartlari.ListeAl(asama, proje, kapali, beyin, Gunluk, TimeProvider.System, Ct);
        Assert.True(yanit.Basarili, $"{yanit.Durum} {yanit.Baslik} {yanit.Ayrinti}");
        return yanit.Veri!;
    }

    [Fact]
    public async Task OpenAnswerAndMoveACodeCard_ThroughTheGateToTheBuild_ThenCancelIt()
    {
        var beyin = Hazirla();
        const string Kimlik = "takvim-sayfasi";

        // The phone opens a card.
        var acilan = Kart(await IsKartlari.Ac(new("Takvim sayfası", "Buluşma takvimi\n- ay görünümü\n- liste görünümü", "kitap-kulubu", null, "kod"), beyin, Gunluk, Ct));
        Assert.Equal((Kimlik, "talep", "vps", "kod", "telefon", "kitap-kulubu", true), (acilan.Kimlik, acilan.Asama, acilan.Sahip, acilan.Tip, acilan.Kaynak, acilan.Proje, acilan.Acik));

        // The VPS plans it and asks one question; the card falls to the person.
        await Vps(beyin, ["is", "asama"], Kimlik, "plan");
        await VpsPlan(beyin, Kimlik, "## Adımlar\n- Ay görünümü\n- Liste görünümü");
        await Vps(beyin, ["is", "soru", "--soru=Takvim için hangi kütüphane?", "--secenek=a", "--secenek=b", "--oneri=a", "--neden=Daha hafif"], Kimlik);
        await Vps(beyin, ["is", "asama", "--sahip=kullanici"], Kimlik, "karar");

        // The list and the detail show what the brain holds.
        var kart = Assert.Single(await Liste(beyin, asama: "karar", proje: "kitap-kulubu"));
        Assert.Equal((Kimlik, "kullanici", 1, true), (kart.Kimlik, kart.Sahip, kart.BekleyenSoru, IsBildirimci.SendeBekliyor(kart)));
        var ayrinti = await Ayrinti(beyin, Kimlik);
        Assert.Contains("ay görünümü", ayrinti.Talep);
        Assert.Contains("Liste görünümü", ayrinti.Plan);
        var s1 = Assert.Single(ayrinti.Sorular);
        Assert.Equal((1, "Takvim için hangi kütüphane?", "a", "Daha hafif", (string?)null), (s1.No, s1.Soru, s1.Onerilen, s1.Neden, s1.Cevap));
        Assert.Equal(["a", "b"], s1.Secenekler);
        Assert.Contains(ayrinti.Gecmis, g => g.Kim == "kullanici" && g.Olay.Contains("oluşturuldu"));

        // The notification would offer the two answers.
        Assert.Equal([("cevap", "a"), ("cevap", "b")], IsKartlari.BildirimSecenekleri(ayrinti).Select(b => (b.Eylem, b.Cevap!)));

        // Leaving the decision with a question open: the brain refuses, the API says so in words, nothing moves.
        var reddedilen = await Asama(beyin, Kimlik, "kod-onayi");
        Assert.Equal((409, "Cevapsız soru var"), (reddedilen.Durum, reddedilen.Baslik));
        Assert.DoesNotContain("/", reddedilen.Ayrinti);
        Assert.Equal("karar", (await Ayrinti(beyin, Kimlik)).Asama);

        // Answer it with words of the person's own, which are not among the options: the brain takes it as it is. A second, different answer is
        // refused (the brain would have overwritten); the same one again is fine.
        const string Serbest = "İkisi de olmasın, kendimiz yazalım";
        var cevaplanan = Kart(await IsKartlari.Cevapla(Kimlik, new(1, Serbest), beyin, Gunluk, Ct));
        Assert.Equal(0, cevaplanan.BekleyenSoru);
        Assert.Equal(409, (await IsKartlari.Cevapla(Kimlik, new(1, "b"), beyin, Gunluk, Ct)).Durum);
        Assert.True((await IsKartlari.Cevapla(Kimlik, new(1, Serbest), beyin, Gunluk, Ct)).Basarili);
        Assert.Equal(Serbest, Assert.Single((await Ayrinti(beyin, Kimlik)).Sorular).Cevap);

        // The brain's rule since 2026-11-11: the last question answered sends the card back to the plan session (the VPS), in the same write.
        var yenidenPlan = await Ayrinti(beyin, Kimlik);
        Assert.Equal(("plan", "vps"), (yenidenPlan.Asama, yenidenPlan.Sahip));
        Assert.Contains(yenidenPlan.Gecmis, g => g.Olay.Contains("yeniden planlama istendi: bütün sorular cevaplandı"));
        // Nothing to ask the person while the card is with the VPS, and it cannot go to the gate from the plan stage.
        Assert.Empty(IsKartlari.BildirimSecenekleri(yenidenPlan));
        Assert.Equal(409, (await Asama(beyin, Kimlik, "kod-onayi")).Durum);

        // The VPS plans again and hands the card back at the decision, which has no open question now; the person moves it on to the gate.
        await Vps(beyin, ["is", "asama", "--sahip=kullanici"], Kimlik, "karar");
        var kodKapisi = Kart(await Asama(beyin, Kimlik, "kod-onayi"));
        Assert.Equal("kod-onayi", kodKapisi.Asama);

        // On the code gate; its notification offers approve and back to plan. The phone shows "Onayla" only when the card's own list
        // of next stages (read off the real brain here) has the stage the gate leads to.
        Assert.All(new[] { "yapim", "plan", "iptal" }, sonraki => Assert.Contains(sonraki, kodKapisi.Gecisler));
        Assert.Equal(["Onayla", "Plana dön"], IsKartlari.BildirimSecenekleri(await Ayrinti(beyin, Kimlik)).Select(b => b.Etiket));

        // Sending the card back to the plan is a revision, and a revision needs a note: the API asks for it before the brain is called
        // (the card stays where it is), and with a note the brain files it and the card is with the VPS again.
        var notsuz = await Asama(beyin, Kimlik, "plan");
        Assert.Equal(400, notsuz.Durum);
        Assert.Equal("kod-onayi", (await Ayrinti(beyin, Kimlik)).Asama);
        var revizyon = Kart(await IsKartlari.AsamaDegistir(Kimlik, new("plan", null, "Kapsamı daralt"), beyin, Gunluk, TimeProvider.System, Ct));
        Assert.Equal(("plan", "vps"), (revizyon.Asama, revizyon.Sahip));
        Assert.Contains((await Ayrinti(beyin, Kimlik)).Gecmis, g => g.Olay.Contains("revizyon: Kapsamı daralt"));
        await Vps(beyin, ["is", "asama", "--sahip=kullanici"], Kimlik, "karar");
        Assert.Equal("kod-onayi", Kart(await Asama(beyin, Kimlik, "kod-onayi")).Asama);

        // Leaving the gate forward: the server adds the approval, the brain accepts it and writes it into the history.
        var yapim = Kart(await Asama(beyin, Kimlik, "yapim"));
        Assert.Equal("yapim", yapim.Asama);
        Assert.Contains(( await Ayrinti(beyin, Kimlik)).Gecmis, g => g.Olay.Contains("onay:telefon-"));
        Assert.Empty(IsKartlari.BildirimSecenekleri(await Ayrinti(beyin, Kimlik)));

        // Cancelling needs a reason; then the card is closed and takes only notes.
        var gerekcesiz = await Asama(beyin, Kimlik, "iptal");
        Assert.Equal(400, gerekcesiz.Durum);
        Assert.Equal("iptal", Kart(await Asama(beyin, Kimlik, "iptal", "Vazgeçtim")).Asama);
        var kapali = await Asama(beyin, Kimlik, "plan");
        Assert.Equal((409, "Kart kapalı"), (kapali.Durum, kapali.Baslik));
        Assert.True((await IsKartlari.NotYaz(Kimlik, new("Sonradan düşünce"), beyin, Gunluk, Ct)).Basarili);
        Assert.Empty(await Liste(beyin));
    }

    [Fact]
    public async Task AGeneralCard_SkipsTheGates_AndShowsInTheClosedListThisWeek()
    {
        var beyin = Hazirla();
        const string Kimlik = "kitap-listesi";

        Kart(await IsKartlari.Ac(new("Kitap listesi", null, null, "ogrenme", "genel"), beyin, Gunluk, Ct));
        await Vps(beyin, ["is", "asama"], Kimlik, "plan");
        await Vps(beyin, ["is", "asama", "--sahip=kullanici"], Kimlik, "karar");

        Assert.Equal("yapim", Kart(await Asama(beyin, Kimlik, "yapim")).Asama);
        var bitti = Kart(await Asama(beyin, Kimlik, "bitti"));
        Assert.False(bitti.Acik);

        Assert.Empty(await Liste(beyin));
        var bu = Assert.Single(await Liste(beyin, kapali: true));
        Assert.Equal((Kimlik, "bitti", "ogrenme"), (bu.Kimlik, bu.Asama, bu.Alan));
    }

    [Fact]
    public async Task ASkippedStage_IsRefusedInWords_AndAnUnknownProjectToo()
    {
        var beyin = Hazirla();
        Kart(await IsKartlari.Ac(new("Deneme", null, "kitap-kulubu", null, null), beyin, Gunluk, Ct));

        var atlama = await Asama(beyin, "deneme", "karar");
        Assert.Equal((409, "Aşama değiştirilemedi"), (atlama.Durum, atlama.Baslik));

        var olmayan = await IsKartlari.Ac(new("Başka", null, "olmayan-proje", null, null), beyin, Gunluk, Ct);
        Assert.Equal((409, "İşlem uygulanamadı"), (olmayan.Durum, olmayan.Baslik));
        Assert.DoesNotContain("projects/", olmayan.Ayrinti);

        var yok = await IsKartlari.Al("olmayan-kart", beyin, Gunluk, Ct);
        Assert.Equal(404, yok.Durum);
    }
}
