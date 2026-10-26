using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using BillSplit.Domain.Enums;

namespace BillSplit.Domain.Entities;

[Table("Debts")]
public class Debt
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid ExpenseId { get; set; }

    [ForeignKey(nameof(ExpenseId))]
    public Expense Expense { get; set; } = null!;

    [Required]
    public Guid CreditorId { get; set; }

    [ForeignKey(nameof(CreditorId))]
    public User Creditor { get; set; } = null!;

    public Guid? DebtorId { get; set; }

    [ForeignKey(nameof(DebtorId))]
    public User? Debtor { get; set; }

    [MaxLength(100)]
    public string? CustomDebtorName { get; set; }

    [MaxLength(20)]
    public string? DebtorPhone { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal Amount { get; set; }

    [Required]
    [MaxLength(10)]
    public string DebtCode { get; set; } = string.Empty; // Format BS + 5 chars, e.g. BS8K2M

    public DebtStatus Status { get; set; } = DebtStatus.Pending;

    public SettlementType? SettlementType { get; set; }

    public DateTime? PaidAt { get; set; }

    public string? BankRawMessage { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
