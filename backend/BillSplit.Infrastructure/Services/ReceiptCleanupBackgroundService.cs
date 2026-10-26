using BillSplit.Application.Interfaces;
using BillSplit.Domain.Enums;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BillSplit.Infrastructure.Services;

public class ReceiptCleanupBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ReceiptCleanupBackgroundService> _logger;

    public ReceiptCleanupBackgroundService(
        IServiceProvider serviceProvider,
        ILogger<ReceiptCleanupBackgroundService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("ReceiptCleanupBackgroundService đã khởi động.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupExpiredReceiptsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi xảy ra trong quá trình dọn dẹp ảnh hóa đơn trên Cloudflare R2.");
            }

            // Quét định kỳ mỗi 24 giờ
            await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
        }
    }

    private async Task CleanupExpiredReceiptsAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var storageService = scope.ServiceProvider.GetRequiredService<IStorageService>();

        var twoWeeksAgo = DateTime.UtcNow.AddDays(-14);

        // Tìm các Expense có ảnh hóa đơn mà tất cả các khoản nợ đã thanh toán và người cuối cùng trả đã quá 14 ngày
        var expensesToClean = await context.Expenses
            .Include(e => e.Debts)
            .Where(e => !string.IsNullOrEmpty(e.ReceiptImageUrl)
                        && e.Debts.Any()
                        && e.Debts.All(d => d.Status == DebtStatus.Paid && d.PaidAt != null && d.PaidAt <= twoWeeksAgo))
            .ToListAsync();

        if (!expensesToClean.Any()) return;

        _logger.LogInformation("Tìm thấy {Count} hóa đơn đã hoàn tất nợ trên 14 ngày cần xóa ảnh.", expensesToClean.Count);

        foreach (var expense in expensesToClean)
        {
            try
            {
                var deleted = await storageService.DeleteFileAsync(expense.ReceiptImageUrl!);
                if (deleted)
                {
                    _logger.LogInformation("Đã xóa ảnh hóa đơn trên R2: {Url}", expense.ReceiptImageUrl);
                }
                expense.ReceiptImageUrl = null;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể xóa ảnh R2 cho ExpenseId: {Id}", expense.Id);
            }
        }

        await context.SaveChangesAsync();
    }
}
