using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Domain.Enums;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class FriendService : IFriendService
{
    private readonly AppDbContext _context;

    public FriendService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<(bool Success, string Message, FriendDto? Data)> AddFriendByPhoneAsync(Guid currentUserId, string phoneNumber)
    {
        var targetUser = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phoneNumber);
        if (targetUser == null)
        {
            return (false, "Không tìm thấy người dùng có số điện thoại này trong hệ thống.", null);
        }

        if (targetUser.Id == currentUserId)
        {
            return (false, "Bạn không thể tự kết bạn với chính mình.", null);
        }

        var existingFriendship = await _context.Friendships.FirstOrDefaultAsync(f =>
            (f.RequesterId == currentUserId && f.AddresseeId == targetUser.Id) ||
            (f.RequesterId == targetUser.Id && f.AddresseeId == currentUserId));

        if (existingFriendship != null)
        {
            if (existingFriendship.Status == FriendshipStatus.Accepted)
            {
                return (false, "Hai người đã là bạn bè từ trước.", null);
            }
            return (false, "Lời mời kết bạn đang chờ phản hồi.", null);
        }

        var friendship = new Friendship
        {
            Id = Guid.NewGuid(),
            RequesterId = currentUserId,
            AddresseeId = targetUser.Id,
            // Chờ người được mời đồng ý, không tự động Accepted, để không lộ thông tin
            // ngân hàng của họ cho người lạ chỉ vì biết đúng số điện thoại.
            Status = FriendshipStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };

        _context.Friendships.Add(friendship);
        await _context.SaveChangesAsync();

        // Chưa lộ số tài khoản/tên ngân hàng của người được mời khi lời mời còn Pending.
        var dto = new FriendDto(
            friendship.Id,
            targetUser.Id,
            targetUser.FullName,
            targetUser.PhoneNumber,
            targetUser.AvatarUrl,
            string.Empty,
            string.Empty,
            string.Empty,
            friendship.Status.ToString(),
            0
        );

        return (true, "Đã gửi lời mời kết bạn, chờ người kia đồng ý.", dto);
    }

    public async Task<(bool Success, string Message)> AcceptFriendRequestAsync(Guid currentUserId, Guid friendshipId)
    {
        var friendship = await _context.Friendships.FirstOrDefaultAsync(f => f.Id == friendshipId && f.AddresseeId == currentUserId);
        if (friendship == null)
        {
            return (false, "Không tìm thấy lời mời kết bạn.");
        }

        friendship.Status = FriendshipStatus.Accepted;
        await _context.SaveChangesAsync();
        return (true, "Đã đồng ý lời mời kết bạn.");
    }

    public async Task<List<FriendDto>> GetPendingRequestsAsync(Guid currentUserId)
    {
        // Chỉ những lời mời người khác gửi ĐẾN mình và đang chờ mình đồng ý.
        // Không lộ số tài khoản/tên ngân hàng của người gửi ở bước này.
        var pending = await _context.Friendships
            .Include(f => f.Requester)
            .Where(f => f.AddresseeId == currentUserId && f.Status == FriendshipStatus.Pending)
            .ToListAsync();

        return pending.Select(f => new FriendDto(
            f.Id,
            f.Requester.Id,
            f.Requester.FullName,
            f.Requester.PhoneNumber,
            f.Requester.AvatarUrl,
            string.Empty,
            string.Empty,
            string.Empty,
            f.Status.ToString(),
            0
        )).ToList();
    }

    public async Task<List<FriendDto>> GetFriendsWithNetBalanceAsync(Guid currentUserId)
    {
        var friendships = await _context.Friendships
            .Include(f => f.Requester)
            .Include(f => f.Addressee)
            .Where(f => (f.RequesterId == currentUserId || f.AddresseeId == currentUserId) && f.Status == FriendshipStatus.Accepted)
            .ToListAsync();

        var result = new List<FriendDto>();

        foreach (var f in friendships)
        {
            var isRequester = f.RequesterId == currentUserId;
            var friendUser = isRequester ? f.Addressee : f.Requester;

            // Tính toán Bù trừ công nợ 2 chiều (Net Balance):
            // Họ nợ mình (mình là Creditor)
            var theyOweMe = await _context.Debts
                .Where(d => d.CreditorId == currentUserId && d.DebtorId == friendUser.Id && d.Status == DebtStatus.Pending)
                .SumAsync(d => (decimal?)d.Amount) ?? 0m;

            // Mình nợ họ (họ là Creditor)
            var iOweThem = await _context.Debts
                .Where(d => d.CreditorId == friendUser.Id && d.DebtorId == currentUserId && d.Status == DebtStatus.Pending)
                .SumAsync(d => (decimal?)d.Amount) ?? 0m;

            var net = theyOweMe - iOweThem; // > 0 là mình cần thu, < 0 là mình cần trả

            result.Add(new FriendDto(
                f.Id,
                friendUser.Id,
                friendUser.FullName,
                friendUser.PhoneNumber,
                friendUser.AvatarUrl,
                friendUser.BankBin,
                friendUser.BankAccountNo,
                friendUser.BankAccountName,
                f.Status.ToString(),
                net
            ));
        }

        return result;
    }
}
