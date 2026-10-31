using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages;

public class IndexModel : PageModel
{
    // The habit panel is the home page for now.
    public IActionResult OnGet() => RedirectToPage("/Aliskanliklar/Index");
}
