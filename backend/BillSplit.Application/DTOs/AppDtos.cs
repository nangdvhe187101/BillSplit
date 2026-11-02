using BillSplit.Domain.Entities;
using BillSplit.Domain.Enums;

namespace BillSplit.Application.DTOs;

// --- DTOs cho BẠN BÈ & BÙ TRỪ CÔNG NỢ ---
public record AddFriendRequestDto(string PhoneNumber);

public record FriendDto(
    Guid Id,
    Guid FriendUserId,
    string FullName,
    string PhoneNumber,
    string? AvatarUrl,
    string BankBin,
    string BankAccountNo,
    string BankAccountName,
    string Status,
    decimal NetBalance // > 0: Bạn nợ mình, < 0: Mình nợ bạn, == 0: Không nợ
);

// --- DTOs cho NHÓM CHIA TIỀN ---
public record CreateGroupRequestDto(string Name, string Category, string? AvatarUrl);

public record JoinGroupRequestDto(string InviteCode);

public record GroupMemberDto(
    Guid UserId,
    string FullName,
    string PhoneNumber,
    string? AvatarUrl,
    string Role,
    DateTime JoinedAt
);

public record GroupDto(
    Guid Id,
    string Name,
    string Category,
    string? AvatarUrl,
    string InviteCode,
    Guid CreatedById,
    DateTime CreatedAt,
    int MemberCount,
    List<GroupMemberDto> Members
);

// --- DTOs cho CHI TIÊU & GẠCH NỢ ---
public record SplitDebtItemDto(
    Guid? DebtorId,
    string? CustomDebtorName,
    decimal Amount
);

public record SplitExpenseRequestDto(
    string Title,
    decimal TotalAmount,
    string Category,
    Guid? GroupId,
    List<SplitDebtItemDto> Debts
);

public record DebtDetailDto(
    Guid Id,
    Guid ExpenseId,
    string ExpenseTitle,
    Guid CreditorId,
    string CreditorName,
    Guid? DebtorId,
    string DebtorName,
    decimal Amount,
    string DebtCode,
    string Status,
    string? SettlementType,
    DateTime? PaidAt,
    DateTime CreatedAt
);

public record PersonDebtSummaryDto(
    Guid? DebtorId,
    string DebtorName,
    string? PhoneNumber,
    decimal TotalPendingAmount,
    int PendingCount,
    decimal TotalPaidAmount,
    int PaidCount,
    List<DebtDetailDto> Debts
);

public record AutoSettleRequestDto(
    string RawBankMessage,
    string? BankShortName
);

public record NetBalanceSummaryDto(
    decimal TotalNetBalance,
    decimal TotalToReceive, // Cần thu về
    decimal TotalToPay       // Cần trả
);

// --- DTOs cho PROFILE NGƯỜI DÙNG & TÀI KHOẢN NGÂN HÀNG ---
public record UpdateProfileRequestDto(
    string FullName,
    string BankBin,
    string BankAccountNo,
    string BankAccountName,
    string? AvatarUrl
);

public record UserProfileDto(
    Guid Id,
    string PhoneNumber,
    string Email,
    string FullName,
    string? AvatarUrl,
    string BankBin,
    string BankAccountNo,
    string BankAccountName,
    string BankName
);

// --- DTOs cho DASHBOARD & THỐNG KÊ TÀI CHÍNH ---
public record CategoryExpenseDto(
    string Category,
    decimal Amount,
    double Percentage
);

public record MonthlyTrendDto(
    string Month, // e.g. "T10", "T11"
    decimal Spent,
    decimal Collected
);

public record DashboardStatsDto(
    decimal TotalReceivable,
    decimal TotalPayable,
    decimal NetBalance,
    List<CategoryExpenseDto> CategoryBreakdown,
    List<MonthlyTrendDto> MonthlyTrends,
    List<DebtDetailDto> RecentTransactions
);

