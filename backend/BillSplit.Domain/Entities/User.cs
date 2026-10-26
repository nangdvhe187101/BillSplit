using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BillSplit.Domain.Entities;

[Table("Users")]
public class User
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(15)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string FullName { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? AvatarUrl { get; set; }

    [Required]
    [MaxLength(10)]
    public string BankBin { get; set; } = string.Empty;

    [Required]
    [MaxLength(30)]
    public string BankAccountNo { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string BankAccountName { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? FcmToken { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public ICollection<Friendship> RequestedFriendships { get; set; } = new List<Friendship>();
    public ICollection<Friendship> ReceivedFriendships { get; set; } = new List<Friendship>();
    public ICollection<GroupMember> GroupMemberships { get; set; } = new List<GroupMember>();
    public ICollection<Expense> PaidExpenses { get; set; } = new List<Expense>();
    public ICollection<Debt> CreditorDebts { get; set; } = new List<Debt>();
    public ICollection<Debt> DebtorDebts { get; set; } = new List<Debt>();
}
