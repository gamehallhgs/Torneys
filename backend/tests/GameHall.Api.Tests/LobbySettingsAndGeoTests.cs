using GameHall.Api.Modules.Geo;
using GameHall.Api.Modules.Teams;
using Xunit;

namespace GameHall.Api.Tests;

public class LobbySettingsTests
{
    [Fact]
    public void Closed_lobby_blocks_join_requests()
    {
        Assert.Equal("lobby_closed",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false, lobbyClosed: true));
        Assert.Null(
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 5, 14, false, lobbyClosed: false));
    }

    [Fact]
    public void Closed_lobby_does_not_hide_more_specific_reasons()
    {
        // Quem já está noutra equipa, não tem idade ou o lobby já está cheio vê esse motivo, não "fechado".
        Assert.Equal("already_in_team",
            TeamRules.JoinBlockedReason(true, false, "registration_open", true, 16, null, 20, 5, 14, false, lobbyClosed: true));
        Assert.Equal("age_too_young",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 15, 5, 14, false, lobbyClosed: true));
        Assert.Equal("team_full",
            TeamRules.JoinBlockedReason(true, false, "registration_open", false, 16, null, 20, 14, 14, false, lobbyClosed: true));
        Assert.Equal("already_member",
            TeamRules.JoinBlockedReason(true, true, "registration_open", false, 16, null, 20, 5, 14, false, lobbyClosed: true));
    }

    [Theory]
    [InlineData(true, true, false, true)]    // líder convida sempre
    [InlineData(true, true, true, true)]
    [InlineData(false, true, false, false)]  // membro sem permissão
    [InlineData(false, true, true, true)]    // membro com permissão do líder
    [InlineData(false, false, true, false)]  // quem não é da equipa nunca convida
    [InlineData(false, false, false, false)]
    public void Who_can_invite(bool isHost, bool isMember, bool membersCanInvite, bool expected) =>
        Assert.Equal(expected, TeamRules.CanInvite(isHost, isMember, membersCanInvite));
}

public class PortugalGeoTests
{
    /// <summary>Sem acentos nem maiúsculas (não depende de ICU/cultura do sistema).</summary>
    private static string Fold(string s) =>
        new string(s.Normalize(System.Text.NormalizationForm.FormD)
            .Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.NonSpacingMark)
            .ToArray()).ToLowerInvariant();

    [Fact]
    public void Has_the_18_districts_and_278_municipalities()
    {
        Assert.Equal(18, PortugalGeo.Districts.Count);
        Assert.Equal(278, PortugalGeo.Districts.Sum(d => d.Municipalities.Count));
    }

    [Fact]
    public void Names_are_unique_and_sorted()
    {
        var names = PortugalGeo.Districts.Select(d => d.Name).ToList();
        Assert.Equal(names.Count, names.Distinct().Count());
        Assert.Equal(names.OrderBy(Fold, StringComparer.Ordinal), names);
        foreach (var d in PortugalGeo.Districts)
        {
            Assert.Equal(d.Municipalities.Count, d.Municipalities.Distinct().Count());
            Assert.NotEmpty(d.Municipalities);
        }
    }

    [Theory]
    [InlineData("Lisboa", "Cascais", true)]
    [InlineData("Porto", "Vila Nova de Gaia", true)]
    [InlineData("Viseu", "Lamego", true)]
    [InlineData("Lisboa", "Porto", false)]       // concelho de outro distrito
    [InlineData("Lisboa", "Atlantis", false)]
    [InlineData("Narnia", "Cascais", false)]
    [InlineData(null, "Cascais", false)]
    [InlineData("Lisboa", null, false)]
    public void Municipality_must_belong_to_district(string? district, string? municipality, bool expected) =>
        Assert.Equal(expected, PortugalGeo.IsMunicipality(district, municipality));

    [Fact]
    public void District_lookup_is_exact()
    {
        Assert.True(PortugalGeo.IsDistrict("Évora"));
        Assert.False(PortugalGeo.IsDistrict("evora"));
        Assert.False(PortugalGeo.IsDistrict(null));
    }
}
