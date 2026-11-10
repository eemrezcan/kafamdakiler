using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Aliskanliklar;

// The shelf lives on the habit's own page now (K-0024); the old address keeps working for bookmarks and old links.
public class RafModel(AppDbContext db) : PageModel
{
    public async Task<IActionResult> OnGetAsync(Guid aliskanlikId, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([aliskanlikId], ct);
        if (a is null)
            return NotFound();

        return RedirectToPage("Detay", null, new { id = a.Id }, a.Tur == AliskanlikTuru.Raf ? "raf" : null);
    }
}
