using SkiaSharp;

namespace Kafamdakiler.Beyin;

// `gelen ekle --gorsel` waits for a ready JPEG; the server stores png and webp too (K-0015), so they are converted here.
public static class JpegCevirici
{
    // A decompression-bomb guard: the 10 MB upload limit does not bound the pixel count.
    public const long EnCokPiksel = 50_000_000;

    // Returns the path to hand to the brain and, when a temporary file was made, the same path to delete afterwards.
    public static (string Yol, string? Gecici) Hazirla(string kaynakYol, string icerikTuru)
    {
        if (icerikTuru == "image/jpeg")
            return (kaynakYol, null);

        using var codec = SKCodec.Create(kaynakYol) ?? throw new InvalidDataException("Fotoğraf okunamadı.");
        if ((long)codec.Info.Width * codec.Info.Height > EnCokPiksel)
            throw new InvalidDataException("Fotoğraf çok büyük (piksel sayısı sınırı aşıldı).");

        using var kaynak = SKBitmap.Decode(codec) ?? throw new InvalidDataException("Fotoğraf çözülemedi.");
        using var sonuc = Yonlendir(kaynak, codec.EncodedOrigin);
        using var veri = SKImage.FromBitmap(sonuc).Encode(SKEncodedImageFormat.Jpeg, 90)
            ?? throw new InvalidDataException("Fotoğraf JPEG'e çevrilemedi.");

        var gecici = Path.Combine(Path.GetTempPath(), "kd-gorsel-" + Guid.NewGuid().ToString("N") + ".jpg");
        try
        {
            using (var akis = File.Create(gecici))
                veri.SaveTo(akis);
            return (gecici, gecici);
        }
        catch
        {
            File.Delete(gecici);
            throw;
        }
    }

    // Draws the image upright (the camera's rotation flag, EXIF) on a white background, since JPEG has no transparency.
    private static SKBitmap Yonlendir(SKBitmap kaynak, SKEncodedOrigin kaynakYonu)
    {
        int w = kaynak.Width, h = kaynak.Height;
        var yanYatmis = kaynakYonu is SKEncodedOrigin.LeftTop or SKEncodedOrigin.RightTop
            or SKEncodedOrigin.RightBottom or SKEncodedOrigin.LeftBottom;

        var hedef = new SKBitmap(yanYatmis ? h : w, yanYatmis ? w : h, SKColorType.Rgba8888, SKAlphaType.Opaque);
        using var tuval = new SKCanvas(hedef);
        tuval.Clear(SKColors.White);
        switch (kaynakYonu)
        {
            case SKEncodedOrigin.TopRight: tuval.Translate(w, 0); tuval.Scale(-1, 1); break;
            case SKEncodedOrigin.BottomRight: tuval.Translate(w, h); tuval.RotateDegrees(180); break;
            case SKEncodedOrigin.BottomLeft: tuval.Translate(0, h); tuval.Scale(1, -1); break;
            case SKEncodedOrigin.LeftTop: tuval.RotateDegrees(90); tuval.Scale(1, -1); break;
            case SKEncodedOrigin.RightTop: tuval.Translate(h, 0); tuval.RotateDegrees(90); break;
            case SKEncodedOrigin.RightBottom: tuval.Translate(h, w); tuval.RotateDegrees(270); tuval.Scale(1, -1); break;
            case SKEncodedOrigin.LeftBottom: tuval.Translate(0, w); tuval.RotateDegrees(-90); break;
        }

        tuval.DrawBitmap(kaynak, 0, 0);
        return hedef;
    }
}
