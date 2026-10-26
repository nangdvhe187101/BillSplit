using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using BillSplit.Domain.Enums;

namespace BillSplit.Domain.Entities;

[Table("Friendships")]
public class Friendship
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid RequesterId { get; set; }

    [ForeignKey(nameof(RequesterId))]
    public User Requester { get; set; } = null!;

    [Required]
    public Guid AddresseeId { get; set; }

    [ForeignKey(nameof(AddresseeId))]
    public User Addressee { get; set; } = null!;

    public FriendshipStatus Status { get; set; } = FriendshipStatus.Pending;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
