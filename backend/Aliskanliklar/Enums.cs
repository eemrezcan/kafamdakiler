namespace Kafamdakiler.Aliskanliklar;

public enum AliskanlikTuru { Sayac, Raf }

public enum Olcu { EvetHayir, Sayili }

public enum HedefYonu { EnAz, EnCok }

public enum Siklik { HerGun, HaftadaN, BelirliGunler }

public enum OgeDurumu { Siradaki, Devam, Bitti, Birakildi }

[Flags]
public enum Gunler
{
    Yok = 0,
    Pzt = 1,
    Sal = 2,
    Car = 4,
    Per = 8,
    Cum = 16,
    Cmt = 32,
    Paz = 64,
}
