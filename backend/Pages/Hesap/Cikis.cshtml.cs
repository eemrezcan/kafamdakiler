using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Hesap;

public class CikisModel : PageModel
{
    private readonly SignInManager<IdentityUser<Guid>> _signInManager;

    public CikisModel(SignInManager<IdentityUser<Guid>> signInManager)
    {
        _signInManager = signInManager;
    }

    // Signing out only happens on POST (protected by the antiforgery token); a plain visit just goes home.
    public IActionResult OnGet() => RedirectToPage("/Index");

    public async Task<IActionResult> OnPostAsync()
    {
        await _signInManager.SignOutAsync();
        return RedirectToPage("/Hesap/Giris");
    }
}
