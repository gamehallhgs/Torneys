using Xunit;
using System.Net;
using GameHall.Api.Infrastructure.Push;
using GameHall.Api.Modules.Notifications;
using GameHall.Api.Modules.Voting;

namespace GameHall.Api.Tests;

/// <summary>Quem recebe o quê: push só nos tipos combinados, email em três, votação só na app.</summary>
public class DeliveryRulesTests
{
    [Fact]
    public void Push_is_exactly_the_agreed_types()
    {
        Assert.Equivalent(
            new[]
            {
                "team_invite", "join_request", "team_confirmed", "slot_reserved", "reservation_expiring",
                "reservation_expired", "game_starting", "game_changed"
            },
            NotificationTypes.PushTypes);
    }

    [Fact]
    public void Email_is_expiring_confirmed_and_slot_reserved()
    {
        Assert.Equivalent(
            new[] { "reservation_expiring", "team_confirmed", "slot_reserved" },
            NotificationTypes.EmailTypes);
    }

    [Theory]
    [InlineData("voting_opened")]
    [InlineData("voting_second_round")]
    [InlineData("voting_results")]
    public void Voting_never_leaves_the_app(string type)
    {
        Assert.DoesNotContain(type, NotificationTypes.PushTypes);
        Assert.DoesNotContain(type, NotificationTypes.EmailTypes);
        Assert.Contains(type, NotificationTypes.InfoTypes);
    }

    [Fact]
    public void Email_types_are_a_subset_of_push_types()
    {
        Assert.All(NotificationTypes.EmailTypes, t => Assert.Contains(t, NotificationTypes.PushTypes));
    }

    [Theory]
    [InlineData(new string[0], "sem votos")]
    [InlineData(new[] { "Ana" }, "Ana")]
    [InlineData(new[] { "Ana", "Rui" }, "Ana e Rui (empate)")]
    [InlineData(new[] { "Ana", "Rui", "Bruno" }, "Ana, Rui e Bruno (empate)")]
    public void Winners_text(string[] names, string expected) => Assert.Equal(expected, VotingTexts.Winners(names));

    [Fact]
    public void Results_text_names_the_winners_and_skips_empty_categories()
    {
        var both = VotingTexts.Results("Taça X", ["Ana"], ["Bruno"]);
        Assert.Contains("Melhor jogador: Ana", both);
        Assert.Contains("Melhor guarda-redes: Bruno", both);

        var onlyPlayer = VotingTexts.Results("Taça X", ["Ana"], []);
        Assert.DoesNotContain("guarda-redes", onlyPlayer);
    }

    [Fact]
    public void Push_texts_are_short_and_name_who_and_where()
    {
        Assert.Equal("Rui convidou-te para a equipa Tubarões.", PushTexts.Invite("Rui", "Tubarões"));
        Assert.Equal("Rui quer entrar na equipa Tubarões.", PushTexts.Request("Rui", "Tubarões"));
    }

    [Theory]
    [InlineData(HttpStatusCode.NotFound, "{}", true)]
    [InlineData(HttpStatusCode.BadRequest, """{"error":{"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token"}}""", true)]
    [InlineData(HttpStatusCode.NotFound, """{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}""", true)]
    [InlineData(HttpStatusCode.InternalServerError, "oops", false)]
    [InlineData(HttpStatusCode.BadRequest, """{"error":{"status":"INVALID_ARGUMENT","message":"Invalid JSON payload"}}""", false)]
    public void Dead_tokens_are_detected(HttpStatusCode status, string body, bool dead) =>
        Assert.Equal(dead, FcmPushSender.IsDeadToken(status, body));
}
