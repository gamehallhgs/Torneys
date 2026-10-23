namespace GameHall.Api.Common;

public static class HttpContextExtensions
{
    /// <summary>IP do cliente (já corrigido pelo proxy, se Security:TrustProxyHeaders estiver ativo).</summary>
    public static string Ip(this HttpContext ctx) =>
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    /// <summary>Id do utilizador autenticado (claim "sub"), se existir.</summary>
    public static Guid? UserId(this HttpContext ctx)
    {
        var value = ctx.User.FindFirst("sub")?.Value;
        return Guid.TryParse(value, out var id) ? id : null;
    }
}
