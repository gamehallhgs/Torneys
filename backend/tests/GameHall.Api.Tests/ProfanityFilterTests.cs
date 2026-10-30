using Xunit;
using GameHall.Api.Common;
using GameHall.Api.Modules.Auth;
using GameHall.Api.Modules.Teams;

namespace GameHall.Api.Tests;

public class ProfanityFilterTests
{
    [Theory]
    [InlineData("caralho")]
    [InlineData("CARALHO")]
    [InlineData("Os Caralhos FC")]
    [InlineData("xcaralhox")]
    [InlineData("c4r4lh0")]
    [InlineData("c.a.r.a.l.h.o")]
    [InlineData("caaaaralho")]
    [InlineData("fodasse")]
    [InlineData("fodase")]
    [InlineData("vai.fodasse")]
    [InlineData("puta")]
    [InlineData("Puta que pariu")]
    [InlineData("a_puta_da_vida")]
    [InlineData("pu7a")]
    [InlineData("puta2")]
    [InlineData("cabrão")]
    [InlineData("Cabrões United")]
    [InlineData("CABRAO")]
    [InlineData("paneleiro")]
    [InlineData("fdp")]
    [InlineData("f0da-se")]
    public void Bad_words_are_refused(string text) => Assert.True(ProfanityFilter.Contains(text));

    [Theory]
    [InlineData("Hugo Dias")]
    [InlineData("Computador FC")]        // "puta" dentro de "computador"
    [InlineData("reputação")]
    [InlineData("disputa")]
    [InlineData("puto")]
    [InlineData("putos do bairro")]
    [InlineData("Imputado")]
    [InlineData("Cabral")]
    [InlineData("Cabrita")]
    [InlineData("Fodão")]
    [InlineData("Scunthorpe")]
    [InlineData("Caravela")]
    [InlineData("Os Tubarões")]
    [InlineData("Águias do Tejo")]
    [InlineData("hugo.dias")]
    [InlineData("ana_2004")]
    [InlineData("")]
    [InlineData(null)]
    public void Normal_names_pass(string? text) => Assert.False(ProfanityFilter.Contains(text));

    [Fact]
    public void Username_with_bad_word_is_invalid_with_the_generic_message()
    {
        Assert.Equal(ProfanityFilter.Message, UsernameRules.Validate("caralho123"));
        Assert.Null(UsernameRules.Validate("hugo.dias"));
    }

    [Fact]
    public void Team_name_with_bad_word_is_invalid()
    {
        Assert.Equal(ProfanityFilter.Message, TeamRules.ValidateName("Os Caralhos"));
        Assert.Null(TeamRules.ValidateName("Os Tubarões"));
    }

    [Fact]
    public void Display_name_with_bad_word_is_invalid()
    {
        Assert.Equal(ProfanityFilter.Message, AuthValidation.DisplayNameProblem("Puta Bonita"));
        Assert.Null(AuthValidation.DisplayNameProblem("Hugo Dias"));
    }

    [Fact]
    public void Every_configured_word_is_refused_itself()
    {
        foreach (var w in ProfanityWords.Anywhere.Concat(ProfanityWords.WholeWord))
        {
            Assert.True(ProfanityFilter.Contains(w), w);
        }
    }
}
