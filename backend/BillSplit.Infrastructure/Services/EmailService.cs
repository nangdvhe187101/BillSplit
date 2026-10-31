using System.Net;
using System.Net.Mail;
using BillSplit.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BillSplit.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody)
    {
        try
        {
            // Mật khẩu ứng dụng Gmail BẮT BUỘC lấy từ cấu hình (User Secrets / biến môi trường),
            // không hardcode trong source code để tránh lộ mật khẩu thật qua lịch sử git.
            var smtpPass = _configuration["Smtp:Password"]
                ?? throw new InvalidOperationException(
                    "Thiếu cấu hình 'Smtp:Password'. Hãy đặt qua biến môi trường Smtp__Password hoặc " +
                    "chạy: dotnet user-secrets set \"Smtp:Password\" \"<mật khẩu ứng dụng Gmail>\"");

            var smtpHost = _configuration["Smtp:Host"] ?? "smtp.gmail.com";
            var smtpPort = int.Parse(_configuration["Smtp:Port"] ?? "587");
            var smtpUser = _configuration["Smtp:Username"]
                ?? throw new InvalidOperationException("Thiếu cấu hình 'Smtp:Username'.");
            var fromName = _configuration["Smtp:SenderName"] ?? "Sổ Nợ";

            using var message = new MailMessage();
            message.From = new MailAddress(smtpUser, fromName);
            message.To.Add(new MailAddress(toEmail));
            message.Subject = subject;
            message.Body = htmlBody;
            message.IsBodyHtml = true;

            using var client = new SmtpClient(smtpHost, smtpPort)
            {
                Credentials = new NetworkCredential(smtpUser, smtpPass.Replace(" ", "")),
                EnableSsl = true
            };

            await client.SendMailAsync(message);
            _logger.LogInformation("Đã gửi email thành công tới {Email}", toEmail);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi gửi email tới {Email}", toEmail);
            return false;
        }
    }
}
