using Kafamdakiler.Bildirimler;

namespace Kafamdakiler.Tests;

// The evidence search is plain text matching, so these are plain unit tests. What must not pass silently is a wrong "done": a
// short id in a sentence, a question taken for a statement, the "next step" line of a card counting as proof.
public class GorevKanitiTests
{
    private const string Kimlik = "mobil-gorunum-duzeltmeleri";
    private const string Baslik = "Mobil görünüm düzeltmeleri";
    private static readonly DateOnly Bugun = new(2026, 11, 9);

    private static KanitSonucu Ara(
        string kimlik = Kimlik, string baslik = Baslik, GitKomiti[]? komitler = null, string? kart = null, GunlukKaydi[]? gunluk = null) =>
        GorevKaniti.Ara(kimlik, baslik, komitler ?? [], kart, gunluk ?? [], Bugun);

    [Fact]
    public void NoEvidenceAtAll_IsYok()
    {
        Assert.Equal(KanitDuzeyi.Yok, Ara().Duzey);
    }

    [Fact]
    public void ACommitThatNamesTheTaskId_IsStrong_WithItsHashAsTheProof()
    {
        var sonuc = Ara(komitler: [new GitKomiti("A1B2C3D4E5F6A7B8C9D0A1B2C3D4E5F6A7B8C9D0", "feat: finish mobil-gorunum-duzeltmeleri pages")]);

        Assert.Equal(KanitDuzeyi.Guclu, sonuc.Duzey);
        Assert.Equal("commit:a1b2c3d4e5f6", sonuc.Kanit);
    }

    [Theory]
    [InlineData("feat: mobil-gorunum-duzeltmeleri-2 first part")]
    [InlineData("fix: xmobil-gorunum-duzeltmeleri")]
    [InlineData("fix: view tweaks for the mobile app")]
    public void ACommitThatOnlyContainsPartOfTheId_IsNotEvidence(string mesaj)
    {
        Assert.Equal(KanitDuzeyi.Yok, Ara(komitler: [new GitKomiti("abcdef1234567", mesaj)]).Duzey);
    }

    [Fact]
    public void AShortTaskId_NeverGivesStrongEvidence()
    {
        // "test" is in a thousand sentences; a commit that says "fix test" has not finished the task called "test".
        var sonuc = Ara(kimlik: "test", baslik: "Test", komitler: [new GitKomiti("abcdef1234567", "fix test")]);

        Assert.Equal(KanitDuzeyi.Yok, sonuc.Duzey);
    }

    [Fact]
    public void ACardLineThatNamesTheIdAndSaysItIsDone_IsStrong_WithADatedWordOfTheUserAsProof()
    {
        var kart = "## 2026-11-09 21:53 · etiket · abc\n  mobil-gorunum-duzeltmeleri bitti, testleri geçti.\n";

        var sonuc = Ara(kart: kart);

        Assert.Equal(KanitDuzeyi.Guclu, sonuc.Duzey);
        Assert.Equal("onay:dogrulama-2026-11-09", sonuc.Kanit);
    }

    [Theory]
    [InlineData("mobil-gorunum-duzeltmeleri bitti mi?")]
    [InlineData("mobil-gorunum-duzeltmeleri bitmedi, yarın devam.")]
    [InlineData("mobil-gorunum-duzeltmeleri-2 bitti.")]
    [InlineData("Sıradaki adım: mobil-gorunum-duzeltmeleri.")]
    public void ACardLineThatDoesNotSayTheTaskIsDone_IsNotStrong(string satir)
    {
        var kart = $"## 2026-11-09 21:53 · etiket · abc\n  {satir}\n";

        Assert.NotEqual(KanitDuzeyi.Guclu, Ara(kart: kart).Duzey);
    }

    [Fact]
    public void TheTitleWordsInTheCard_AreWeak_AndASentenceAboutOtherWork_IsNot()
    {
        var kart = "## 2026-11-09 21:53 · etiket · abc\n  Mobil görünüm düzeltmeleri üzerinde çalışıldı.\n";
        var baskasi = "## 2026-11-09 21:53 · etiket · abc\n  Bildirim kanalı yayında.\n";

        Assert.Equal(KanitDuzeyi.Zayif, Ara(kart: kart).Duzey);
        Assert.Equal(KanitDuzeyi.Yok, Ara(kart: baskasi).Duzey);
    }

    [Fact]
    public void TheNextStepLineOfTheCard_NeverCountsAsWeakEvidence()
    {
        // The line names work still to do: the words of the title are exactly what it is about.
        var kart = "## 2026-11-09 21:53 · etiket · abc\n  Sıradaki adım: mobil görünüm düzeltmeleri yapılacak.\n";

        Assert.Equal(KanitDuzeyi.Yok, Ara(kart: kart).Duzey);
    }

    [Fact]
    public void TheTitleWordsInOneJournalEntry_AreWeak_ButWordsSpreadOverEntriesAreNot()
    {
        var birlikte = new GunlukKaydi("Mobil", "görünüm düzeltmeleri bitti");
        var dagnik = new[] { new GunlukKaydi("Mobil", null), new GunlukKaydi("Görünüm", null), new GunlukKaydi("Düzeltmeleri", null) };

        Assert.Equal(KanitDuzeyi.Zayif, Ara(gunluk: [birlikte]).Duzey);
        Assert.Equal(KanitDuzeyi.Yok, Ara(gunluk: dagnik).Duzey);
    }

    [Fact]
    public void ATitleWithTooFewSignificantWords_GetsNoWeakEvidence()
    {
        // "Test yaz": "yaz" is too short to carry meaning, "test" alone matches everything.
        Assert.Equal(KanitDuzeyi.Yok, Ara(kimlik: "test-yaz", baslik: "Test yaz", kart: "## 2026-11-09 21:53 · e · o\n  test yaz\n").Duzey);
    }

    [Fact]
    public void StrongBeatsWeak_AndACommitBeatsTheCard()
    {
        var kart = "## 2026-11-09 21:53 · e · o\n  mobil-gorunum-duzeltmeleri bitti\n";
        var sonuc = Ara(komitler: [new GitKomiti("abcdef1234567890", "mobil-gorunum-duzeltmeleri")], kart: kart);

        Assert.Equal(KanitDuzeyi.Guclu, sonuc.Duzey);
        Assert.StartsWith("commit:", sonuc.Kanit);
    }

    [Fact]
    public void SonKart_TakesTheNewestBlockWhateverTheOrder()
    {
        var govde = "# Kartlar\n\n## 2026-11-06 22:16 · eski · a1\n  eski içerik\n\n## 2026-11-09 21:53 · yeni · b2\n  yeni içerik\n\n## 2026-11-08 10:00 · orta · c3\n  orta içerik\n";

        var kart = GorevKaniti.SonKart(govde);

        Assert.Contains("yeni içerik", kart);
        Assert.DoesNotContain("eski içerik", kart);
        Assert.DoesNotContain("orta içerik", kart);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("hiç kart yok")]
    public void SonKart_WithoutBlocks_IsNull(string? govde)
    {
        Assert.Null(GorevKaniti.SonKart(govde));
    }
}
