using System.Text.RegularExpressions;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Domain.Enums;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class DebtService : IDebtService
{
    private readonly AppDbContext _context;

    public DebtService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<(bool Success, string Message, List<DebtDetailDto>? Debts)> SplitExpenseAsync(Guid creditorId, SplitExpenseRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return (false, "Tiêu đề hóa đơn không được để trống.", null);
        }

        if (request.TotalAmount <= 0)
        {
            return (false, "Tổng tiền hóa đơn phải lớn hơn 0.", null);
        }

        if (request.Debts == null || !request.Debts.Any())
        {
            return (false, "Phải có ít nhất 1 người chia tiền.", null);
        }

        var sumDebts = request.Debts.Sum(d => d.Amount);
        if (Math.Abs(sumDebts - request.TotalAmount) > 1m)
        {
            return (false, $"Tổng các phần chia ({sumDebts:N0} đ) không khớp với hóa đơn ({request.TotalAmount:N0} đ).", null);
        }

        var expense = new Expense
        {
            Id = Guid.NewGuid(),
            Title = request.Title.Trim(),
            TotalAmount = request.TotalAmount,
            PayerId = creditorId,
            GroupId = request.GroupId,
            Category = request.Category,
            CreatedAt = DateTime.UtcNow
        };

        _context.Expenses.Add(expense);

        var creditor = await _context.Users.FindAsync(creditorId);
        var createdDebts = new List<Debt>();
        var resultDtos = new List<DebtDetailDto>();

        foreach (var item in request.Debts)
        {
            var debtCode = GenerateDebtCode();
            while (await _context.Debts.AnyAsync(d => d.DebtCode == debtCode))
            {
                debtCode = GenerateDebtCode();
            }

            string debtorName = item.CustomDebtorName ?? "Thành viên";
            if (item.DebtorId.HasValue)
            {
                var debtorUser = await _context.Users.FindAsync(item.DebtorId.Value);
                if (debtorUser != null)
                {
                    debtorName = debtorUser.FullName;
                }
            }

            var debt = new Debt
            {
                Id = Guid.NewGuid(),
                ExpenseId = expense.Id,
                CreditorId = creditorId,
                DebtorId = item.DebtorId,
                CustomDebtorName = item.CustomDebtorName,
                Amount = item.Amount,
                DebtCode = debtCode,
                Status = DebtStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            createdDebts.Add(debt);

            resultDtos.Add(new DebtDetailDto(
                debt.Id,
                expense.Id,
                expense.Title,
                creditorId,
                creditor?.FullName ?? "Chủ nợ",
                debt.DebtorId,
                debtorName,
                debt.Amount,
                debt.DebtCode,
                debt.Status.ToString(),
                null,
                null,
                debt.CreatedAt
            ));
        }

        _context.Debts.AddRange(createdDebts);
        await _context.SaveChangesAsync();

        return (true, "Tạo bill chia nợ thành công!", resultDtos);
    }

    public async Task<NetBalanceSummaryDto> GetNetBalanceSummaryAsync(Guid userId)
    {
        // Tiền cần thu về (người khác nợ mình)
        var toReceive = await _context.Debts
            .Where(d => d.CreditorId == userId && d.Status == DebtStatus.Pending)
            .SumAsync(d => (decimal?)d.Amount) ?? 0m;

        // Tiền cần trả (mình nợ người khác)
        var toPay = await _context.Debts
            .Where(d => d.DebtorId == userId && d.Status == DebtStatus.Pending)
            .SumAsync(d => (decimal?)d.Amount) ?? 0m;

        var net = toReceive - toPay;

        return new NetBalanceSummaryDto(net, toReceive, toPay);
    }

    public async Task<List<DebtDetailDto>> GetDebtsAsync(Guid userId, string? status, bool asCreditor)
    {
        var query = _context.Debts
            .Include(d => d.Expense)
            .Include(d => d.Creditor)
            .Include(d => d.Debtor)
            .AsQueryable();

        if (asCreditor)
        {
            query = query.Where(d => d.CreditorId == userId);
        }
        else
        {
            query = query.Where(d => d.DebtorId == userId);
        }

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<DebtStatus>(status, true, out var parsedStatus))
        {
            query = query.Where(d => d.Status == parsedStatus);
        }

        var list = await query.OrderByDescending(d => d.CreatedAt).ToListAsync();

        return list.Select(d => new DebtDetailDto(
            d.Id,
            d.ExpenseId,
            d.Expense.Title,
            d.CreditorId,
            d.Creditor.FullName,
            d.DebtorId,
            d.Debtor?.FullName ?? d.CustomDebtorName ?? "Khách ngoài",
            d.Amount,
            d.DebtCode,
            d.Status.ToString(),
            d.SettlementType?.ToString(),
            d.PaidAt,
            d.CreatedAt
        )).ToList();
    }

    public async Task<(bool Success, string Message, DebtDetailDto? SettledDebt)> AutoSettleByMessageAsync(Guid creditorId, AutoSettleRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.RawBankMessage))
        {
            return (false, "Nội dung tin nhắn ngân hàng trống.", null);
        }

        // Regex bóc tách mã nợ BSxxxxx
        var regex = new Regex(@"\bBS[A-Za-z0-9]{4,6}\b", RegexOptions.IgnoreCase);
        var match = regex.Match(request.RawBankMessage);

        if (!match.Success)
        {
            return (false, "Không tìm thấy mã nợ hợp lệ (BSxxxxx) trong tin nhắn biến động số dư.", null);
        }

        var debtCode = match.Value.ToUpper();

        var debt = await _context.Debts
            .Include(d => d.Expense)
            .Include(d => d.Creditor)
            .Include(d => d.Debtor)
            .FirstOrDefaultAsync(d => d.DebtCode == debtCode && d.CreditorId == creditorId);

        if (debt == null)
        {
            return (false, $"Không tìm thấy khoản nợ tương ứng với mã {debtCode}.", null);
        }

        if (debt.Status == DebtStatus.Paid)
        {
            return (false, $"Khoản nợ {debtCode} đã được gạch nợ trước đó.", null);
        }

        // Không chỉ tin vào mã nợ tìm được trong tin nhắn: phải đối chiếu số tiền
        // biến động trong tin nhắn có khớp với số tiền nợ thật thì mới tự động gạch nợ.
        // Việc này ngăn một tin nhắn giả (hoặc bị sửa) với số tiền sai/0 đồng vẫn được
        // chấp nhận chỉ vì chứa đúng mã BSxxxxx.
        var parsedAmount = ExtractAmount(request.RawBankMessage);
        if (parsedAmount == null)
        {
            return (false, "Không tìm thấy số tiền biến động hợp lệ trong tin nhắn ngân hàng.", null);
        }

        if (Math.Abs(parsedAmount.Value - debt.Amount) > 1m)
        {
            return (false,
                $"Số tiền trong tin nhắn ({parsedAmount:N0} đ) không khớp với số tiền cần thu ({debt.Amount:N0} đ) của mã {debtCode}.",
                null);
        }

        debt.Status = DebtStatus.Paid;
        debt.SettlementType = SettlementType.Auto;
        debt.PaidAt = DateTime.UtcNow;
        debt.BankRawMessage = request.RawBankMessage;

        await _context.SaveChangesAsync();

        var dto = new DebtDetailDto(
            debt.Id,
            debt.ExpenseId,
            debt.Expense.Title,
            debt.CreditorId,
            debt.Creditor.FullName,
            debt.DebtorId,
            debt.Debtor?.FullName ?? debt.CustomDebtorName ?? "Khách ngoài",
            debt.Amount,
            debt.DebtCode,
            debt.Status.ToString(),
            debt.SettlementType.ToString(),
            debt.PaidAt,
            debt.CreatedAt
        );

        return (true, $"Tự động gạch nợ thành công cho mã {debtCode} ({debt.Amount:N0} đ)!", dto);
    }

    public async Task<(bool Success, string Message)> ManualSettleAsync(Guid creditorId, Guid debtId)
    {
        var debt = await _context.Debts.FirstOrDefaultAsync(d => d.Id == debtId && d.CreditorId == creditorId);
        if (debt == null)
        {
            return (false, "Không tìm thấy khoản nợ này.");
        }

        if (debt.Status == DebtStatus.Paid)
        {
            return (false, "Khoản nợ này đã được thanh toán từ trước.");
        }

        debt.Status = DebtStatus.Paid;
        debt.SettlementType = SettlementType.Manual;
        debt.PaidAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return (true, "Đã xác nhận gạch nợ thủ công thành công!");
    }

    // Bóc tách số tiền biến động số dư từ nội dung thông báo ngân hàng, ví dụ:
    // "+55,000VND" / "-55.000đ" / "Số dư tăng 55000 VND". Lấy số tiền lớn nhất,
    // hợp lệ (>= 1.000đ) tìm được, vì tin nhắn ngân hàng thường chỉ chứa 1 số tiền.
    private static decimal? ExtractAmount(string rawMessage)
    {
        var matches = Regex.Matches(rawMessage, @"\d{1,3}(?:[.,]\d{3})+|\d{4,}");
        decimal? best = null;

        foreach (Match m in matches)
        {
            var cleaned = m.Value.Replace(".", "").Replace(",", "");
            if (decimal.TryParse(cleaned, out var value) && value >= 1000m)
            {
                if (best == null || value > best.Value)
                {
                    best = value;
                }
            }
        }

        return best;
    }

    private static string GenerateDebtCode()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = new Random();
        var suffix = new string(Enumerable.Repeat(chars, 5).Select(s => s[random.Next(s.Length)]).ToArray());
        return $"BS{suffix}";
    }
}
