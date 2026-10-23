namespace GameHall.Api.Modules.Legal;

public static class LegalEndpoints
{
    public static void MapLegalEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/v1/legal").AllowAnonymous();

        // Versões atuais (a app compara com as que o utilizador aceitou).
        g.MapGet("/current", (LegalDocuments legal) => Results.Ok(new
        {
            terms = new { version = legal.Terms.Version },
            privacy = new { version = legal.Privacy.Version }
        }));

        // Texto completo (Markdown). type = terms | privacy
        g.MapGet("/{type}", (string type, LegalDocuments legal) =>
        {
            var doc = legal.Get(type);
            return doc is null
                ? Results.NotFound()
                : Results.Ok(new { type = doc.Type, version = doc.Version, language = "pt-PT", text = doc.Text });
        });
    }
}
