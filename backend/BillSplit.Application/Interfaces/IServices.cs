using BillSplit.Application.DTOs;
using BillSplit.Domain.Entities;

namespace BillSplit.Application.Interfaces;

public interface ITokenService
{
    string GenerateToken(User user);
}

public interface IAuthService
{
    Task<(bool Success, string Message, AuthResponseDto? Data)> RegisterAsync(RegisterRequestDto request);
    Task<(bool Success, string Message, AuthResponseDto? Data)> LoginAsync(LoginRequestDto request);
    Task<(bool Success, string Message)> SendOtpAsync(SendOtpRequestDto request);
    Task<(bool Success, string Message)> VerifyOtpAsync(VerifyOtpRequestDto request);
    Task<(bool Success, string Message)> ForgotPasswordAsync(string email);
    Task<(bool Success, string Message)> ResetPasswordAsync(ResetPasswordRequestDto request);
}

public interface IBankService
{
    Task<List<BankDto>> GetAllBanksAsync();
    Task SeedDefaultBanksAsync();
}

public interface IFriendService
{
    Task<(bool Success, string Message, FriendDto? Data)> AddFriendByPhoneAsync(Guid currentUserId, string phoneNumber);
    Task<(bool Success, string Message)> AcceptFriendRequestAsync(Guid currentUserId, Guid friendshipId);
    Task<List<FriendDto>> GetFriendsWithNetBalanceAsync(Guid currentUserId);
    Task<List<FriendDto>> GetPendingRequestsAsync(Guid currentUserId);
}

public interface IGroupService
{
    Task<(bool Success, string Message, GroupDto? Data)> CreateGroupAsync(Guid currentUserId, CreateGroupRequestDto request);
    Task<List<GroupDto>> GetUserGroupsAsync(Guid currentUserId);
    Task<GroupDto?> GetGroupDetailAsync(Guid currentUserId, Guid groupId);
    Task<(bool Success, string Message, GroupDto? Data)> JoinGroupByInviteCodeAsync(Guid currentUserId, string inviteCode);
}

public interface IDebtService
{
    Task<(bool Success, string Message, List<DebtDetailDto>? Debts)> SplitExpenseAsync(Guid creditorId, SplitExpenseRequestDto request);
    Task<NetBalanceSummaryDto> GetNetBalanceSummaryAsync(Guid userId);
    Task<List<DebtDetailDto>> GetDebtsAsync(Guid userId, string? status, bool asCreditor);
    Task<List<PersonDebtSummaryDto>> GetDebtsGroupedByPersonAsync(Guid userId, bool asCreditor);
    Task<(bool Success, string Message, DebtDetailDto? SettledDebt)> AutoSettleByMessageAsync(Guid creditorId, AutoSettleRequestDto request);
    Task<(bool Success, string Message)> ManualSettleAsync(Guid creditorId, Guid debtId);
}

public interface IUserService
{
    Task<UserProfileDto?> GetProfileAsync(Guid userId);
    Task<(bool Success, string Message, UserProfileDto? Data)> UpdateProfileAsync(Guid userId, UpdateProfileRequestDto request);
}

public interface IStatisticsService
{
    Task<DashboardStatsDto> GetDashboardStatsAsync(Guid userId);
}



