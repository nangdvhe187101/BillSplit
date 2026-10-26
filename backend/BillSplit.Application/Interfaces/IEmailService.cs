namespace BillSplit.Application.Interfaces;

public interface IEmailService
{
    Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody);
}
