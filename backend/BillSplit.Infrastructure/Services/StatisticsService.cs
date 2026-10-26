using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Enums;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class StatisticsService : IStatisticsService
{
    private readonly AppDbContext _context;

    public StatisticsService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<DashboardStatsDto> GetDashboardStatsAsync(Guid userId)
    {
        // 1. Tính tổng công nợ
        var creditorDebts = await _context.Debts
            .AsNoTracking()
            .Include(d => d.Expense)
            .Include(d => d.Debtor)
            .Include(d => d.Creditor)
            .Where(d => d.CreditorId == userId)
            .ToListAsync();

        var debtorDebts = await _context.Debts
            .AsNoTracking()
            .Include(d => d.Expense)
            .Include(d => d.Debtor)
            .Include(d => d.Creditor)
            .Where(d => d.DebtorId == userId)
            .ToListAsync();

        var totalReceivable = creditorDebts
            .Where(d => d.Status == DebtStatus.Pending)
            .Sum(d => d.Amount);

        var totalPayable = debtorDebts
            .Where(d => d.Status == DebtStatus.Pending)
            .Sum(d => d.Amount);

        var netBalance = totalReceivable - totalPayable;

        // 2. Thống kê chi tiêu theo danh mục (từ các khoản chi tiêu người dùng đã trả hoặc tham gia)
        var userExpenses = await _context.Expenses
            .AsNoTracking()
            .Where(e => e.PayerId == userId)
            .ToListAsync();

        var categoryMap = new Dictionary<string, decimal>();
        foreach (var exp in userExpenses)
        {
            var cat = string.IsNullOrWhiteSpace(exp.Category) ? "Khác" : exp.Category;
            if (!categoryMap.ContainsKey(cat))
            {
                categoryMap[cat] = 0;
            }
            categoryMap[cat] += exp.TotalAmount;
        }

        var totalExpenseAmount = categoryMap.Values.Sum();
        var categoryBreakdown = new List<CategoryExpenseDto>();

        if (totalExpenseAmount > 0)
        {
            foreach (var kvp in categoryMap.OrderByDescending(x => x.Value))
            {
                var percentage = Math.Round((double)(kvp.Value / totalExpenseAmount) * 100, 1);
                categoryBreakdown.Add(new CategoryExpenseDto(kvp.Key, kvp.Value, percentage));
            }
        }
        else
        {
            // Mẫu danh mục mặc định nếu chưa có chi tiêu
            categoryBreakdown.Add(new CategoryExpenseDto("Ăn uống", 0, 0));
        }

        // 3. Xu hướng 4 tháng gần nhất
        var now = DateTime.UtcNow;
        var monthlyTrends = new List<MonthlyTrendDto>();
        for (int i = 3; i >= 0; i--)
        {
            var targetMonth = now.AddMonths(-i);
            var monthLabel = $"T{targetMonth.Month}";

            var monthSpent = userExpenses
                .Where(e => e.CreatedAt.Year == targetMonth.Year && e.CreatedAt.Month == targetMonth.Month)
                .Sum(e => e.TotalAmount);

            var monthCollected = creditorDebts
                .Where(d => d.Status == DebtStatus.Paid && d.PaidAt.HasValue &&
                            d.PaidAt.Value.Year == targetMonth.Year && d.PaidAt.Value.Month == targetMonth.Month)
                .Sum(d => d.Amount);

            monthlyTrends.Add(new MonthlyTrendDto(monthLabel, monthSpent, monthCollected));
        }

        // 4. Các giao dịch gần đây (kết hợp các khoản nợ cần thu hoặc cần trả)
        var recentDebts = creditorDebts.Concat(debtorDebts)
            .OrderByDescending(d => d.CreatedAt)
            .Take(5)
            .Select(d => new DebtDetailDto(
                d.Id,
                d.ExpenseId,
                d.Expense?.Title ?? "Khoản chi",
                d.CreditorId,
                d.Creditor?.FullName ?? "Chủ nợ",
                d.DebtorId,
                d.Debtor?.FullName ?? d.CustomDebtorName ?? "Người nợ",
                d.Amount,
                d.DebtCode,
                d.Status.ToString(),
                d.SettlementType?.ToString(),
                d.PaidAt,
                d.CreatedAt
            ))
            .ToList();

        return new DashboardStatsDto(
            totalReceivable,
            totalPayable,
            netBalance,
            categoryBreakdown,
            monthlyTrends,
            recentDebts
        );
    }
}
