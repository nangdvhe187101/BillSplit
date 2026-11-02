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

    private static string NormalizePhone(string phone)
    {
        if (string.IsNullOrWhiteSpace(phone)) return string.Empty;
        var digits = new string(phone.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("84") && digits.Length >= 10)
        {
            digits = "0" + digits.Substring(2);
        }
        return digits;
    }

    public async Task<(bool Success, string Message, FriendDto? Data)> AddFriendByPhoneAsync(Guid currentUserId, string phoneNumber)
    {
        var cleanPhone = NormalizePhone(phoneNumber);
        if (string.IsNullOrWhiteSpace(cleanPhone))
        {
            return (false, "Vui lòng nhập số điện thoại hợp lệ.", null);
        }

        var intlPhone = cleanPhone.StartsWith("0") ? "84" + cleanPhone.Substring(1) : cleanPhone;
        var plusIntlPhone = "+" + intlPhone;

        var targetUser = await _context.Users.FirstOrDefaultAsync(u =>
            u.PhoneNumber == cleanPhone ||
            u.PhoneNumber == phoneNumber.Trim() ||
            u.PhoneNumber == intlPhone ||
            u.PhoneNumber == plusIntlPhone);

        if (targetUser == null)
        {
            return (false, "Số điện thoại này chưa đăng ký tài khoản BillSplit. Hãy nhờ bạn bè tải app và đăng ký tài khoản trước nhé!", null);
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
            // Kích hoạt ngay mối quan hệ bạn bè nếu trước đó còn đang Pending
            existingFriendship.Status = FriendshipStatus.Accepted;
            await _context.SaveChangesAsync();

            var acceptedDto = new FriendDto(
                existingFriendship.Id,
                targetUser.Id,
                targetUser.FullName,
                targetUser.PhoneNumber,
                targetUser.AvatarUrl,
                targetUser.BankBin,
                targetUser.BankAccountNo,
                targetUser.BankAccountName,
                existingFriendship.Status.ToString(),
                0
            );
            return (true, "Đã thêm bạn bè thành công!", acceptedDto);
        }

        var friendship = new Friendship
        {
            Id = Guid.NewGuid(),
            RequesterId = currentUserId,
            AddresseeId = targetUser.Id,
            // Tự động kết nối bạn bè ngay để có thể chia bill và tính nợ
            Status = FriendshipStatus.Accepted,
            CreatedAt = DateTime.UtcNow
        };

        _context.Friendships.Add(friendship);
        await _context.SaveChangesAsync();

        var dto = new FriendDto(
            friendship.Id,
            targetUser.Id,
            targetUser.FullName,
            targetUser.PhoneNumber,
            targetUser.AvatarUrl,
            targetUser.BankBin,
            targetUser.BankAccountNo,
            targetUser.BankAccountName,
            friendship.Status.ToString(),
            0
        );

        return (true, "Đã thêm bạn bè thành công!", dto);
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
