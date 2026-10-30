using GameHall.Api.Modules.Notifications;
using Xunit;

namespace GameHall.Api.Tests;

public class NotificationTextsTests
{
    [Theory]
    [InlineData(0, "0 €")]
    [InlineData(5000, "50 €")]
    [InlineData(715, "7,15 €")]
    [InlineData(705, "7,05 €")]
    public void Money_is_formatted_in_portuguese(int cents, string expected) =>
        Assert.Equal(expected, NotificationTexts.Money(cents));

    [Fact]
    public void Split_tells_everyone_to_pay_their_share()
    {
        var host = NotificationTexts.Payment("split", 715, true, true, 30);
        var member = NotificationTexts.Payment("split", 715, false, true, 30);
        Assert.Contains("7,15 €", host);
        Assert.Contains("30 minutos para pagar", host);
        Assert.Contains("7,15 €", member);
        Assert.Contains("30 minutos para pagar", member);
    }

    [Fact]
    public void Total_only_the_host_pays()
    {
        var host = NotificationTexts.Payment("total", 5000, true, true, 30);
        var member = NotificationTexts.Payment("total", 5000, false, true, 30);
        Assert.Contains("Pagas 50 €", host);
        Assert.Contains("não tens de pagar", member);
    }

    [Fact]
    public void Queue_says_there_is_no_slot_yet()
    {
        var text = NotificationTexts.Payment("split", 715, false, false, 30);
        Assert.Contains("fila", text);
        Assert.DoesNotContain("minutos para pagar", text);
    }

    [Fact]
    public void Closed_and_reserved_messages_name_team_and_tournament()
    {
        var closed = NotificationTexts.Closed("Leões", "Taça Verão", "split", 715, false, true, 30);
        Assert.Contains("Leões", closed);
        Assert.Contains("Taça Verão", closed);
        var reserved = NotificationTexts.SlotReserved("Leões", "Taça Verão", "total", 5000, true, 30);
        Assert.Contains("vaga", reserved);
        Assert.Contains("Pagas 50 €", reserved);
        Assert.Contains("confirmada", NotificationTexts.Confirmed("Leões", "Taça Verão"));
    }

    [Fact]
    public void Lifecycle_texts()
    {
        Assert.Contains("aceitou", NotificationTexts.RequestAccepted("Leões", "Taça"));
        Assert.Contains("recusou", NotificationTexts.RequestRejected("Leões", "Taça"));
        Assert.Contains("penalizado", NotificationTexts.Expiring("Leões", 5, true));
        Assert.DoesNotContain("penalizado", NotificationTexts.Expiring("Leões", 5, false));
        Assert.Contains("15 minutos", NotificationTexts.Expired("Leões", true, 15));
        Assert.Contains("não pagas nada", NotificationTexts.Expired("Leões", false, 15));
        Assert.Contains("inscrições terminaram", NotificationTexts.Eliminated("Leões", "Taça", true));
        Assert.Contains("vagas ficaram confirmadas", NotificationTexts.Eliminated("Leões", "Taça", false));
    }
}
