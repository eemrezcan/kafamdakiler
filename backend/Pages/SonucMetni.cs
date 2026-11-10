using Microsoft.AspNetCore.Http.HttpResults;

namespace Kafamdakiler.Pages;

// What a minimal-API answer (the assistant's service speaks in them) says, as a sentence for the person: the problem's detail, or its field
// messages. Null when the answer is a success.
public static class SonucMetni
{
    public static string? Hata(IResult sonuc) => sonuc switch
    {
        IStatusCodeHttpResult { StatusCode: >= 200 and < 300 } => null,
        ProblemHttpResult { ProblemDetails: HttpValidationProblemDetails dogrulama } => string.Join(" ", dogrulama.Errors.Values.SelectMany(m => m)),
        ProblemHttpResult sorun => sorun.ProblemDetails.Detail ?? sorun.ProblemDetails.Title ?? "İşlem yapılamadı.",
        IStatusCodeHttpResult { StatusCode: StatusCodes.Status404NotFound } => "Bulunamadı; silinmiş olabilir.",
        IStatusCodeHttpResult { StatusCode: StatusCodes.Status401Unauthorized } => "Oturum süresi dolmuş; yeniden giriş yap.",
        _ => "İşlem yapılamadı.",
    };
}
