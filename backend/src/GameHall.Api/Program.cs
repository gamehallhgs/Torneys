using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using GameHall.Api.Common;
using GameHall.Api.Database;
using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Infrastructure.Security;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Legal;
using GameHall.Api.Modules.Me;
using GameHall.Api.Modules.Games;
using GameHall.Api.Modules.Geo;
using GameHall.Api.Modules.Teams;
using GameHall.Api.Modules.Tournaments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

DapperConfig.Register();

var builder = WebApplication.CreateBuilder(args);

// ---------- Configuração e validação no arranque ----------

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.Section));
builder.Services.Configure<SecurityOptions>(builder.Configuration.GetSection(SecurityOptions.Section));
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.Section));
builder.Services.Configure<LegalOptions>(builder.Configuration.GetSection(LegalOptions.Section));

var jwt = builder.Configuration.GetSection(JwtOptions.Section).Get<JwtOptions>() ?? new JwtOptions();
var security = builder.Configuration.GetSection(SecurityOptions.Section).Get<SecurityOptions>() ?? new SecurityOptions();
var connectionString = builder.Configuration.GetConnectionString("Default");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("Falta a configuração ConnectionStrings:Default.");
}

if (jwt.SigningKey.Length < 32)
{
    throw new InvalidOperationException("Jwt:SigningKey tem de ter pelo menos 32 caracteres.");
}

if (security.Pepper.Length < 16)
{
    throw new InvalidOperationException("Security:Pepper tem de ter pelo menos 16 caracteres.");
}

if (builder.Environment.IsProduction() &&
    (jwt.SigningKey.Contains("dev-only", StringComparison.OrdinalIgnoreCase) ||
     security.Pepper.Contains("dev-only", StringComparison.OrdinalIgnoreCase)))
{
    throw new InvalidOperationException("Em produção não podes usar os segredos de desenvolvimento (\"dev-only\").");
}

// ---------- Serviços ----------

builder.WebHost.ConfigureKestrel(o =>
{
    o.AddServerHeader = false;
    o.Limits.MaxRequestBodySize = 64 * 1024; // pedidos JSON pequenos; uploads de vídeo terão limite próprio
});

builder.Services.AddSingleton<NpgsqlDataSource>(_ => NpgsqlDataSource.Create(connectionString));
builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddTransient<Migrator>();
builder.Services.AddSingleton<AuthStore>();
builder.Services.AddSingleton<TournamentStore>();
builder.Services.AddSingleton<GameStore>();
builder.Services.AddSingleton<TeamStore>();
builder.Services.AddScoped<TeamService>();
builder.Services.AddSingleton<TeamConfirmationService>();
builder.Services.AddHostedService<RegistrationLifecycleService>();
builder.Services.AddSingleton<PasswordHasher>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<LegalDocuments>();
builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();
builder.Services.AddScoped<AuthService>();

builder.Services.AddHttpClient<PwnedPasswordChecker>(c =>
{
    c.BaseAddress = new Uri("https://api.pwnedpasswords.com/");
    c.Timeout = TimeSpan.FromSeconds(3);
});

builder.Services
    .AddAuthentication(Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false; // mantém os nomes "sub" e "role" tal como no token
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = "sub",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorizationBuilder()
    // Por defeito, TODOS os endpoints exigem sessão E termos em dia. As exceções (login, registo,
    // /me...) declaram-no explicitamente com AllowAnonymous ou a política "Authenticated".
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .RequireClaim("legal_ok", "true")
        .Build())
    .AddPolicy("Authenticated", p => p.RequireAuthenticatedUser())
    .AddPolicy("Admin", p => p.RequireAuthenticatedUser().RequireClaim("role", "Admin"));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Limite geral por IP
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(ctx.Ip(), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 300,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        }));

    // Login, registo, refresh: 10 por minuto por IP
    o.AddPolicy("auth", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(ctx.Ip(), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = builder.Environment.IsDevelopment() ? 100 : 10,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        }));

    // Códigos por email, reposição de palavra-passe, eliminar conta: 5 por 15 minutos por IP
    o.AddPolicy("sensitive", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(ctx.Ip(), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = builder.Environment.IsDevelopment() ? 100 : 5,
            Window = TimeSpan.FromMinutes(15),
            QueueLimit = 0
        }));

    o.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        await context.HttpContext.Response.WriteAsJsonAsync(
            new { code = "rate_limited", title = "Demasiados pedidos. Tenta novamente daqui a pouco." }, token);
    };
});

builder.Services.AddProblemDetails();

// CORS só em Development: permite correr a app Flutter no browser (flutter run -d chrome) contra a API local.
// Em produção não existe CORS (a app móvel não precisa).
builder.Services.AddCors(o => o.AddPolicy("DevWeb", p => p
    .SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var u)
        && (u.Host == "localhost" || u.Host == "127.0.0.1"))
    .AllowAnyHeader()
    .AllowAnyMethod()));

// ---------- Pipeline ----------

var app = builder.Build();

if (builder.Configuration.GetValue("Database:AutoMigrate", true))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<Migrator>().RunAsync(CancellationToken.None);
}

// Falha cedo (no arranque) se os textos legais não carregarem.
_ = app.Services.GetRequiredService<LegalDocuments>();

if (app.Environment.IsDevelopment())
{
    // Antes do handler de exceções: assim até as respostas de erro (500) têm cabeçalhos CORS
    // e o browser mostra o erro real em vez de "falha de rede".
    app.UseCors("DevWeb");
}

app.UseExceptionHandler();

if (security.TrustProxyHeaders)
{
    // Só ativar quando a API NÃO está exposta diretamente (só atrás do Caddy/Nginx, que define X-Forwarded-For).
    app.Use(async (ctx, next) =>
    {
        var forwarded = ctx.Request.Headers["X-Forwarded-For"].ToString();
        if (!string.IsNullOrEmpty(forwarded) && IPAddress.TryParse(forwarded.Split(',')[0].Trim(), out var clientIp))
        {
            ctx.Connection.RemoteIpAddress = clientIp;
        }

        await next();
    });
}

app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "DENY";
    ctx.Response.Headers["Referrer-Policy"] = "no-referrer";
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
    ctx.Response.Headers["Cache-Control"] = "no-store";
    await next();
});

app.UseStatusCodePages();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" })).AllowAnonymous();

app.MapGet("/health/ready", async (NpgsqlDataSource db, CancellationToken ct) =>
{
    await using var conn = await db.OpenConnectionAsync(ct);
    await using var cmd = new NpgsqlCommand("SELECT 1", conn);
    await cmd.ExecuteScalarAsync(ct);
    return Results.Ok(new { status = "ready" });
}).AllowAnonymous();

app.MapLegalEndpoints();
app.MapAuthEndpoints();
app.MapMeEndpoints();
app.MapTournamentEndpoints();
app.MapGameEndpoints();
app.MapGeoEndpoints();
app.MapTeamEndpoints();

app.Run();

// Necessário para testes de integração futuros (WebApplicationFactory<Program>)
public partial class Program { }
