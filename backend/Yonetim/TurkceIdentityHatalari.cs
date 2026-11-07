using Microsoft.AspNetCore.Identity;

namespace Kafamdakiler.Yonetim;

// Identity's own messages are English. Every place that shows a password error (the Razor pages, /api/yonetim,
// and the ready-made /api/hesap/manage/info the mobile app calls) gets the Turkish text from here.
// Only the errors a password change can raise are translated; the rest keep Identity's text.
public class TurkceIdentityHatalari : IdentityErrorDescriber
{
    public override IdentityError PasswordTooShort(int length) =>
        Hata(nameof(PasswordTooShort), $"Şifre en az {length} karakter olmalı.");

    public override IdentityError PasswordRequiresDigit() =>
        Hata(nameof(PasswordRequiresDigit), "Şifre en az bir rakam içermeli (0-9).");

    public override IdentityError PasswordRequiresLower() =>
        Hata(nameof(PasswordRequiresLower), "Şifre en az bir küçük harf içermeli (a-z).");

    public override IdentityError PasswordRequiresUpper() =>
        Hata(nameof(PasswordRequiresUpper), "Şifre en az bir büyük harf içermeli (A-Z).");

    public override IdentityError PasswordRequiresNonAlphanumeric() =>
        Hata(nameof(PasswordRequiresNonAlphanumeric), "Şifre en az bir harf ve rakam olmayan karakter içermeli (örneğin !).");

    public override IdentityError PasswordRequiresUniqueChars(int uniqueChars) =>
        Hata(nameof(PasswordRequiresUniqueChars), $"Şifre en az {uniqueChars} farklı karakter içermeli.");

    public override IdentityError PasswordMismatch() =>
        Hata(nameof(PasswordMismatch), "Mevcut şifre yanlış.");

    private static IdentityError Hata(string kod, string aciklama) => new() { Code = kod, Description = aciklama };
}
