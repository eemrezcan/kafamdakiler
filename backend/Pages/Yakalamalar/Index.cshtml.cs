using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Yakalamalar;

// The captures list lives in the inbox now (/Gelen, under "Gönderiliyor"). The old address keeps working for bookmarks and old
// links by redirecting there. /Yakalamalar/Duzenle stays: it is the edit page.
public class IndexModel : PageModel
{
    public IActionResult OnGet() => RedirectToPage("/Gelen/Index");
}
