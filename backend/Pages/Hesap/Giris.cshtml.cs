using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Hesap;

public class GirisModel : PageModel
{
    private readonly SignInManager<IdentityUser<Guid>> _signInManager;

    public GirisModel(SignInManager<IdentityUser<Guid>> signInManager)
    {
        _signInManager = signInManager;
    }

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required(ErrorMessage = "E-posta zorunlu.")]
        [EmailAddress(ErrorMessage = "Geçerli bir e-posta yaz.")]
        [Display(Name = "E-posta")]
        public string Email { get; set; } = "";

        [Required(ErrorMessage = "Şifre zorunlu.")]
        [DataType(DataType.Password)]
        [Display(Name = "Şifre")]
        public string Sifre { get; set; } = "";
    }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(string? returnUrl = null)
    {
        if (!ModelState.IsValid)
            return Page();

        var result = await _signInManager.PasswordSignInAsync(Input.Email, Input.Sifre, isPersistent: false, lockoutOnFailure: true);

        if (result.Succeeded)
        {
            // Only redirect inside this site, never to a URL taken from the query string as-is.
            return LocalRedirect(Url.IsLocalUrl(returnUrl) ? returnUrl : Url.Content("~/"));
        }

        if (result.IsLockedOut)
            ModelState.AddModelError(string.Empty, "Çok fazla hatalı deneme. Biraz sonra tekrar dene.");
        else
            ModelState.AddModelError(string.Empty, "E-posta ya da şifre yanlış.");

        return Page();
    }
}
