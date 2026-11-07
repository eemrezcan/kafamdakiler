using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Hesap;

// The signed-in user changes their own password. The /Hesap folder is open to anonymous visitors (the sign-in page
// lives there), and an anonymous rule outranks [Authorize], so this page asks for a sign-in itself.
public class SifreModel(UserManager<IdentityUser<Guid>> kullanicilar, SignInManager<IdentityUser<Guid>> girisYoneticisi) : PageModel
{
    [BindProperty]
    public InputModel Input { get; set; } = new();

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public class InputModel
    {
        [Required(ErrorMessage = "Mevcut şifre zorunlu.")]
        [DataType(DataType.Password)]
        [Display(Name = "Mevcut şifre")]
        public string MevcutSifre { get; set; } = "";

        [Required(ErrorMessage = "Yeni şifre zorunlu.")]
        [DataType(DataType.Password)]
        [Display(Name = "Yeni şifre")]
        public string YeniSifre { get; set; } = "";

        [Required(ErrorMessage = "Şifreyi tekrar yaz.")]
        [Compare(nameof(YeniSifre), ErrorMessage = "Şifreler aynı değil.")]
        [DataType(DataType.Password)]
        [Display(Name = "Yeni şifre (tekrar)")]
        public string YeniSifreTekrar { get; set; } = "";
    }

    public IActionResult OnGet() => GirisYapildiMi ? Page() : GirisIste();

    public async Task<IActionResult> OnPostAsync()
    {
        if (!GirisYapildiMi)
            return GirisIste();

        if (!ModelState.IsValid)
            return Page();

        var kullanici = await kullanicilar.GetUserAsync(User);
        if (kullanici is null)
            return GirisIste();

        var sonuc = await kullanicilar.ChangePasswordAsync(kullanici, Input.MevcutSifre, Input.YeniSifre);
        if (!sonuc.Succeeded)
        {
            foreach (var hata in sonuc.Errors)
            {
                var alan = hata.Code == nameof(IdentityErrorDescriber.PasswordMismatch) ? nameof(Input.MevcutSifre) : nameof(Input.YeniSifre);
                ModelState.AddModelError($"{nameof(Input)}.{alan}", hata.Description);
            }

            return Page();
        }

        // The password change renews the security stamp, which would sign this browser out on its next check:
        // sign in again with the new stamp so the user stays on the site.
        await girisYoneticisi.RefreshSignInAsync(kullanici);
        Bildirim = "Şifren değişti";
        return RedirectToPage();
    }

    private bool GirisYapildiMi => User.Identity?.IsAuthenticated == true;

    // The cookie scheme sends the browser to the sign-in page and back here afterwards.
    private ChallengeResult GirisIste() => Challenge(IdentityConstants.ApplicationScheme);
}
