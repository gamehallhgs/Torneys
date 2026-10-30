using GameHall.Api.Infrastructure.Email;
using GameHall.Api.Infrastructure.Push;
using GameHall.Api.Infrastructure.Security;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Games;
using GameHall.Api.Modules.Geo;
using GameHall.Api.Modules.Legal;
using GameHall.Api.Modules.Me;
using GameHall.Api.Modules.Notifications;
using GameHall.Api.Modules.Teams;
using GameHall.Api.Modules.Tournaments;
using GameHall.Api.Modules.Voting;

namespace GameHall.Api;

/// <summary>
/// Um sítio só para ver (e mudar) o que cada módulo regista: serviços, tarefas em segundo plano e rotas.
/// Para criar um módulo novo (ex.: gestor, árbitro, pagamentos): pasta em Modules/, um método AddXModule aqui
/// e um MapXModule com as rotas. Os módulos falam entre si por serviços/lojas, nunca por SQL de outro módulo.
/// </summary>
public static class ModuleRegistration
{
    public static IServiceCollection AddAuthModule(this IServiceCollection s)
    {
        s.AddSingleton<AuthStore>();
        s.AddSingleton<UsernameStore>();
        s.AddSingleton<PasswordHasher>();
        s.AddSingleton<TokenService>();
        s.AddSingleton<IEmailSender, SmtpEmailSender>();
        s.AddScoped<AuthService>();
        return s;
    }

    public static IServiceCollection AddLegalModule(this IServiceCollection s)
    {
        s.AddSingleton<LegalDocuments>();
        return s;
    }

    public static IServiceCollection AddTournamentsModule(this IServiceCollection s)
    {
        s.AddSingleton<TournamentStore>();
        s.AddHostedService<TournamentLifecycleService>();
        return s;
    }

    public static IServiceCollection AddGamesModule(this IServiceCollection s)
    {
        s.AddSingleton<GameStore>();
        s.AddSingleton<GameStartingService>();
        s.AddHostedService(sp => sp.GetRequiredService<GameStartingService>());
        return s;
    }

    public static IServiceCollection AddTeamsModule(this IServiceCollection s)
    {
        s.AddSingleton<TeamStore>();
        s.AddScoped<TeamService>();
        s.AddSingleton<ReservationService>();
        s.AddHostedService<ReservationWorker>();
        s.AddHostedService<RegistrationLifecycleService>();
        return s;
    }

    public static IServiceCollection AddVotingModule(this IServiceCollection s)
    {
        s.AddSingleton<VotingStore>();
        s.AddScoped<VotingService>();
        s.AddSingleton<VotingNotificationService>();
        s.AddHostedService(sp => sp.GetRequiredService<VotingNotificationService>());
        return s;
    }

    public static IServiceCollection AddNotificationsModule(this IServiceCollection s)
    {
        s.AddSingleton<NotificationStore>();
        s.AddSingleton<NotificationDispatcher>();
        s.AddHostedService(sp => sp.GetRequiredService<NotificationDispatcher>());
        return s;
    }

    public static WebApplication MapModules(this WebApplication app)
    {
        app.MapLegalEndpoints();
        app.MapAuthEndpoints();
        app.MapMeEndpoints();
        app.MapUsernameEndpoints();
        app.MapTournamentEndpoints();
        app.MapGameEndpoints();
        app.MapVotingEndpoints();
        app.MapGeoEndpoints();
        app.MapTeamEndpoints();
        app.MapNotificationEndpoints();
        return app;
    }
}
