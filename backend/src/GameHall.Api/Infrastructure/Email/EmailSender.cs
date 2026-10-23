using GameHall.Api.Common;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace GameHall.Api.Infrastructure.Email;

public interface IEmailSender
{
    Task SendAsync(string to, string subject, string textBody, CancellationToken ct);
}

/// <summary>Envio por SMTP. Em desenvolvimento aponta para o MailHog (porta 1025, sem TLS).</summary>
public sealed class SmtpEmailSender(IOptions<SmtpOptions> options) : IEmailSender
{
    public async Task SendAsync(string to, string subject, string textBody, CancellationToken ct)
    {
        var o = options.Value;

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(o.FromName, o.FromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("plain") { Text = textBody };

        using var client = new SmtpClient();
        await client.ConnectAsync(
            o.Host, o.Port, o.UseTls ? SecureSocketOptions.StartTls : SecureSocketOptions.None, ct);

        if (!string.IsNullOrEmpty(o.User))
        {
            await client.AuthenticateAsync(o.User, o.Password, ct);
        }

        await client.SendAsync(message, ct);
        await client.DisconnectAsync(true, ct);
    }
}
