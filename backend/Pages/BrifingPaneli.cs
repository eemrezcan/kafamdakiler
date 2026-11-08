using Kafamdakiler.Brifing;

namespace Kafamdakiler.Pages;

// What the briefing panel strip at the top of the home page ("Bugün") shows: today's briefing, or the reason there is none (not due yet, could not be made).
public record BrifingPaneli(BrifingDto? Brifing, string? Mesaj);
