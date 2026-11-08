using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Beyin;

// The day plan lives on the home page now. The old addresses (/Beyin/Gun and /Beyin/Gun/2026-11-03) keep working
// for bookmarks and old links by redirecting to / and /2026-11-03.
public partial class GunModel : PageModel
{
    [GeneratedRegex(@"^\d{4}-\d{2}-\d{2}$")]
    private static partial Regex TarihBicimi();

    public IActionResult OnGet(string? tarih)
    {
        if (string.IsNullOrEmpty(tarih))
            return RedirectToPage("/Index");

        // The home page only takes dates; anything else was never a day plan.
        return TarihBicimi().IsMatch(tarih) ? RedirectToPage("/Index", new { tarih }) : NotFound();
    }
}
