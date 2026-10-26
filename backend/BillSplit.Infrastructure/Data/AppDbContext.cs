using BillSplit.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Bank> Banks => Set<Bank>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();
    public DbSet<Expense> Expenses => Set<Expense>();
    public DbSet<Debt> Debts => Set<Debt>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Users
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.PhoneNumber).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
        });

        // Banks
        modelBuilder.Entity<Bank>(entity =>
        {
            entity.HasIndex(b => b.ShortName);
        });

        // Friendships
        modelBuilder.Entity<Friendship>(entity =>
        {
            entity.HasIndex(f => new { f.RequesterId, f.AddresseeId }).IsUnique();

            entity.HasOne(f => f.Requester)
                  .WithMany(u => u.RequestedFriendships)
                  .HasForeignKey(f => f.RequesterId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(f => f.Addressee)
                  .WithMany(u => u.ReceivedFriendships)
                  .HasForeignKey(f => f.AddresseeId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // Groups
        modelBuilder.Entity<Group>(entity =>
        {
            entity.HasIndex(g => g.InviteCode).IsUnique();

            entity.HasOne(g => g.CreatedBy)
                  .WithMany()
                  .HasForeignKey(g => g.CreatedById)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // GroupMembers (Composite Key)
        modelBuilder.Entity<GroupMember>(entity =>
        {
            entity.HasKey(gm => new { gm.GroupId, gm.UserId });

            entity.HasOne(gm => gm.Group)
                  .WithMany(g => g.Members)
                  .HasForeignKey(gm => gm.GroupId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(gm => gm.User)
                  .WithMany(u => u.GroupMemberships)
                  .HasForeignKey(gm => gm.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // Expenses
        modelBuilder.Entity<Expense>(entity =>
        {
            entity.HasOne(e => e.Payer)
                  .WithMany(u => u.PaidExpenses)
                  .HasForeignKey(e => e.PayerId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Group)
                  .WithMany(g => g.Expenses)
                  .HasForeignKey(e => e.GroupId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // Debts
        modelBuilder.Entity<Debt>(entity =>
        {
            entity.HasIndex(d => d.DebtCode).IsUnique();

            entity.HasOne(d => d.Expense)
                  .WithMany(e => e.Debts)
                  .HasForeignKey(d => d.ExpenseId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(d => d.Creditor)
                  .WithMany(u => u.CreditorDebts)
                  .HasForeignKey(d => d.CreditorId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(d => d.Debtor)
                  .WithMany(u => u.DebtorDebts)
                  .HasForeignKey(d => d.DebtorId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
