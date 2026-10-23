using GameHall.Api.Common;
using GameHall.Api.Infrastructure.Security;
using GameHall.Api.Modules.Auth;
using Microsoft.Extensions.Options;
using Xunit;

namespace GameHall.Api.Tests;

public class PasswordHasherTests
{
    private static PasswordHasher Create(string pepper = "test-pepper-0123456789abcdef") =>
        new(Options.Create(new SecurityOptions { Pepper = pepper }));

    [Fact]
    public void Hash_then_verify_succeeds_with_correct_password()
    {
        var hasher = Create();
        var hash = hasher.Hash("uma palavra-passe bem comprida 42");

        Assert.StartsWith("$argon2id$v=19$m=65536,t=3,p=2$", hash);
        Assert.True(hasher.Verify("uma palavra-passe bem comprida 42", hash));
    }

    [Fact]
    public void Verify_fails_with_wrong_password()
    {
        var hasher = Create();
        var hash = hasher.Hash("uma palavra-passe bem comprida 42");

        Assert.False(hasher.Verify("outra palavra-passe diferente 42", hash));
    }

    [Fact]
    public void Same_password_produces_different_hashes_because_of_salt()
    {
        var hasher = Create();

        Assert.NotEqual(hasher.Hash("repetida repetida 123"), hasher.Hash("repetida repetida 123"));
    }

    [Fact]
    public void Hash_made_with_one_pepper_does_not_verify_with_another()
    {
        var hash = Create("pepper-A-0123456789abcdef").Hash("palavra-passe-segura-99");

        Assert.False(Create("pepper-B-0123456789abcdef").Verify("palavra-passe-segura-99", hash));
    }

    [Fact]
    public void Verify_returns_false_for_malformed_hash()
    {
        var hasher = Create();

        Assert.False(hasher.Verify("x", "isto-nao-e-um-hash"));
        Assert.False(hasher.Verify("x", "$argon2id$v=19$m=abc,t=3,p=2$AAAA$BBBB"));
    }

    [Fact]
    public void Current_hash_does_not_need_rehash()
    {
        var hasher = Create();

        Assert.False(hasher.NeedsRehash(hasher.Hash("palavra-passe-segura-99")));
    }
}

public class PasswordPolicyTests
{
    [Theory]
    [InlineData("curta1")]
    [InlineData("")]
    public void Rejects_short_or_empty(string password)
    {
        Assert.NotEmpty(PasswordPolicy.Validate(password, "a@b.pt", "Nome"));
    }

    [Fact]
    public void Rejects_common_and_repetitive_passwords()
    {
        Assert.Contains("too_common", PasswordPolicy.Validate("password1234", "a@b.pt", "Nome"));
        Assert.Contains("too_common", PasswordPolicy.Validate("aaaaaaaaaaaaaaaa", "a@b.pt", "Nome"));
    }

    [Fact]
    public void Rejects_password_containing_email_local_part()
    {
        Assert.Contains("contains_email", PasswordPolicy.Validate("joaosilva-2024-xyz", "joaosilva@mail.pt", "Outro"));
    }

    [Fact]
    public void Accepts_long_passphrase_without_composition_rules()
    {
        Assert.Empty(PasswordPolicy.Validate("cavalo bateria agrafo certo", "ana@mail.pt", "Ana"));
    }

    [Fact]
    public void Rejects_too_long()
    {
        Assert.Contains("too_long", PasswordPolicy.Validate(new string('x', 129) + "abc", "a@b.pt", "Nome"));
    }
}

public class AgeCalculatorTests
{
    [Fact]
    public void Turns_thirteen_exactly_on_birthday()
    {
        var birth = new DateOnly(2013, 6, 15);

        Assert.Equal(12, AgeCalculator.AgeOn(birth, new DateOnly(2026, 6, 14)));
        Assert.Equal(13, AgeCalculator.AgeOn(birth, new DateOnly(2026, 6, 15)));
    }

    [Fact]
    public void Handles_leap_day_birthdays()
    {
        var birth = new DateOnly(2012, 2, 29);

        // Em anos não bissextos, quem nasceu a 29 de fevereiro faz anos a 28 de fevereiro.
        Assert.Equal(12, AgeCalculator.AgeOn(birth, new DateOnly(2025, 2, 27)));
        Assert.Equal(13, AgeCalculator.AgeOn(birth, new DateOnly(2025, 2, 28)));
        Assert.Equal(13, AgeCalculator.AgeOn(birth, new DateOnly(2025, 3, 1)));
    }
}

public class AuthValidationTests
{
    [Theory]
    [InlineData("  Ana@Mail.PT ", "ana@mail.pt")]
    [InlineData("a.b+tag@exemplo.com", "a.b+tag@exemplo.com")]
    public void Normalizes_valid_emails(string input, string expected)
    {
        Assert.Equal(expected, AuthValidation.NormalizeEmail(input));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("sem-arroba")]
    [InlineData("dois@@mail.pt")]
    [InlineData("Nome <ana@mail.pt>")]
    [InlineData("ana@semponto")]
    [InlineData("ana @mail.pt")]
    public void Rejects_invalid_emails(string? input)
    {
        Assert.Null(AuthValidation.NormalizeEmail(input));
    }

    [Theory]
    [InlineData("A", false)]
    [InlineData("Ana", true)]
    [InlineData("Nome\nComQuebra", false)]
    public void Validates_display_names(string name, bool valid)
    {
        Assert.Equal(valid, AuthValidation.IsValidDisplayName(name));
    }
}

public class HashingTests
{
    [Fact]
    public void Hmac_is_deterministic_and_separated_by_purpose()
    {
        var a = Hashing.Hmac("chave-secreta-0123456789", "ip", "1.2.3.4");
        var b = Hashing.Hmac("chave-secreta-0123456789", "ip", "1.2.3.4");
        var c = Hashing.Hmac("chave-secreta-0123456789", "emailcode", "1.2.3.4");

        Assert.Equal(a, b);
        Assert.NotEqual(a, c);
    }

    [Fact]
    public void Sha256_matches_known_vector()
    {
        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", Hashing.Sha256Hex("abc"));
    }
}

public class TokenServiceTests
{
    [Fact]
    public void Refresh_tokens_are_long_random_and_unique()
    {
        var a = TokenService.NewRefreshToken();
        var b = TokenService.NewRefreshToken();

        Assert.NotEqual(a, b);
        Assert.True(a.Length >= 40);
    }

    [Fact]
    public void Access_token_contains_expected_claims()
    {
        var service = new TokenService(
            Options.Create(new JwtOptions { SigningKey = "chave-de-teste-com-mais-de-32-caracteres-123" }),
            TimeProvider.System);
        var user = new User { Id = Guid.NewGuid(), Role = UserRole.Referee };

        var (token, expiresIn) = service.CreateAccessToken(user, legalOk: true);
        var payload = System.Text.Encoding.UTF8.GetString(
            System.Buffers.Text.Base64Url.DecodeFromChars(token.Split('.')[1]));

        Assert.Equal(15 * 60, expiresIn);
        Assert.Contains(user.Id.ToString(), payload);
        Assert.Contains("\"role\":\"Referee\"", payload);
        Assert.Contains("\"legal_ok\":\"true\"", payload);
    }
}
