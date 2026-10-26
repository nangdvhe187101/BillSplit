using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using BillSplit.Domain.Entities;
using BillSplit.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace BillSplit.Infrastructure.Services;

public class BankService : IBankService
{
    private readonly AppDbContext _context;

    public BankService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<BankDto>> GetAllBanksAsync()
    {
        var banks = await _context.Banks
            .AsNoTracking()
            .OrderBy(b => b.ShortName)
            .Select(b => new BankDto
            {
                Bin = b.Bin,
                ShortName = b.ShortName,
                FullName = b.FullName,
                LogoUrl = b.LogoUrl,
                IsSupported = b.IsSupported
            })
            .ToListAsync();

        return banks;
    }

    public async Task SeedDefaultBanksAsync()
    {
        if (await _context.Banks.AnyAsync())
        {
            return;
        }

        var defaultBanks = GetComprehensiveBankList();

        _context.Banks.AddRange(defaultBanks);
        await _context.SaveChangesAsync();
    }

    public static List<Bank> GetComprehensiveBankList()
    {
        return new List<Bank>
        {
            // --- VÍ ĐIỆN TỬ & NGÂN HÀNG SỐ PHỔ BIẾN ---
            new() { Bin = "971005", ShortName = "MoMo", FullName = "Ví điện tử MoMo", LogoUrl = "https://api.vietqr.io/img/MOMO.png" },
            new() { Bin = "971011", ShortName = "ZaloPay", FullName = "Ví điện tử ZaloPay", LogoUrl = "https://api.vietqr.io/img/ZALOPAY.png" },
            new() { Bin = "971003", ShortName = "Viettel Money", FullName = "Tổng Công ty Dịch vụ Số Viettel", LogoUrl = "https://api.vietqr.io/img/VIETTELMONEY.png" },
            new() { Bin = "971008", ShortName = "VNPT Money", FullName = "Tập đoàn Bưu chính Viễn thông Việt Nam", LogoUrl = "https://api.vietqr.io/img/VNPTMONEY.png" },
            new() { Bin = "971010", ShortName = "ShopeePay", FullName = "Ví điện tử ShopeePay", LogoUrl = "https://api.vietqr.io/img/SHOPEEPAY.png" },
            new() { Bin = "546034", ShortName = "CAKE", FullName = "Ngân hàng số Cake by VPBank", LogoUrl = "https://api.vietqr.io/img/CAKE.png" },
            new() { Bin = "963388", ShortName = "Timo", FullName = "Ngân hàng số Timo by BVBank", LogoUrl = "https://api.vietqr.io/img/TIMO.png" },

            // --- CÁC NGÂN HÀNG THƯƠNG MẠI LỚN TẠI VIỆT NAM ---
            new() { Bin = "970422", ShortName = "MBBank", FullName = "Ngân hàng TMCP Quân đội", LogoUrl = "https://api.vietqr.io/img/MB.png" },
            new() { Bin = "970423", ShortName = "TPBank", FullName = "Ngân hàng TMCP Tiên Phong", LogoUrl = "https://api.vietqr.io/img/TPB.png" },
            new() { Bin = "970436", ShortName = "Vietcombank", FullName = "Ngân hàng TMCP Ngoại thương Việt Nam", LogoUrl = "https://api.vietqr.io/img/VCB.png" },
            new() { Bin = "970415", ShortName = "VietinBank", FullName = "Ngân hàng TMCP Công thương Việt Nam", LogoUrl = "https://api.vietqr.io/img/CTG.png" },
            new() { Bin = "970418", ShortName = "BIDV", FullName = "Ngân hàng TMCP Đầu tư và Phát triển Việt Nam", LogoUrl = "https://api.vietqr.io/img/BIDV.png" },
            new() { Bin = "970407", ShortName = "Techcombank", FullName = "Ngân hàng TMCP Kỹ thương Việt Nam", LogoUrl = "https://api.vietqr.io/img/TCB.png" },
            new() { Bin = "970416", ShortName = "ACB", FullName = "Ngân hàng TMCP Á Châu", LogoUrl = "https://api.vietqr.io/img/ACB.png" },
            new() { Bin = "970432", ShortName = "VPBank", FullName = "Ngân hàng TMCP Việt Nam Thịnh Vượng", LogoUrl = "https://api.vietqr.io/img/VPB.png" },
            new() { Bin = "970403", ShortName = "Sacombank", FullName = "Ngân hàng TMCP Sài Gòn Thương Tín", LogoUrl = "https://api.vietqr.io/img/STB.png" },
            new() { Bin = "970441", ShortName = "VIB", FullName = "Ngân hàng TMCP Quốc tế Việt Nam", LogoUrl = "https://api.vietqr.io/img/VIB.png" },
            new() { Bin = "970437", ShortName = "HDBank", FullName = "Ngân hàng TMCP Phát triển TP.HCM", LogoUrl = "https://api.vietqr.io/img/HDB.png" },
            new() { Bin = "970448", ShortName = "OCB", FullName = "Ngân hàng TMCP Phương Đông", LogoUrl = "https://api.vietqr.io/img/OCB.png" },
            new() { Bin = "970405", ShortName = "Agribank", FullName = "Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam", LogoUrl = "https://api.vietqr.io/img/VBA.png" },
            new() { Bin = "970426", ShortName = "MSB", FullName = "Ngân hàng TMCP Hàng Hải Việt Nam", LogoUrl = "https://api.vietqr.io/img/MSB.png" },
            new() { Bin = "970440", ShortName = "SeABank", FullName = "Ngân hàng TMCP Đông Nam Á", LogoUrl = "https://api.vietqr.io/img/SEAB.png" },
            new() { Bin = "970449", ShortName = "LPBank", FullName = "Ngân hàng TMCP Lộc Phát Việt Nam", LogoUrl = "https://api.vietqr.io/img/LPB.png" },
            new() { Bin = "970428", ShortName = "Nam A Bank", FullName = "Ngân hàng TMCP Nam Á", LogoUrl = "https://api.vietqr.io/img/NAB.png" },
            new() { Bin = "970454", ShortName = "BVBank", FullName = "Ngân hàng TMCP Bản Việt", LogoUrl = "https://api.vietqr.io/img/BVB.png" },
            new() { Bin = "970409", ShortName = "Bac A Bank", FullName = "Ngân hàng TMCP Bắc Á", LogoUrl = "https://api.vietqr.io/img/BAB.png" },
            new() { Bin = "970412", ShortName = "PVcomBank", FullName = "Ngân hàng TMCP Đại Chúng Việt Nam", LogoUrl = "https://api.vietqr.io/img/PVCB.png" },
            new() { Bin = "970452", ShortName = "Kienlongbank", FullName = "Ngân hàng TMCP Kiên Long", LogoUrl = "https://api.vietqr.io/img/KLB.png" },
            new() { Bin = "970400", ShortName = "Saigonbank", FullName = "Ngân hàng TMCP Sài Gòn Công Thương", LogoUrl = "https://api.vietqr.io/img/SGB.png" },
            new() { Bin = "970438", ShortName = "BaoViet Bank", FullName = "Ngân hàng TMCP Bảo Việt", LogoUrl = "https://api.vietqr.io/img/BVBANK.png" },
            new() { Bin = "970430", ShortName = "PGBank", FullName = "Ngân hàng TMCP Thịnh vượng và Phát triển", LogoUrl = "https://api.vietqr.io/img/PGB.png" },
            new() { Bin = "970424", ShortName = "Shinhan Bank", FullName = "Ngân hàng TNHH MTV Shinhan Việt Nam", LogoUrl = "https://api.vietqr.io/img/SHBVN.png" },
            new() { Bin = "970457", ShortName = "Woori Bank", FullName = "Ngân hàng TNHH MTV Woori Việt Nam", LogoUrl = "https://api.vietqr.io/img/WVN.png" },
            new() { Bin = "970458", ShortName = "UOB", FullName = "Ngân hàng UOB Việt Nam", LogoUrl = "https://api.vietqr.io/img/UOB.png" },
            new() { Bin = "970439", ShortName = "Public Bank", FullName = "Ngân hàng Public Bank Việt Nam", LogoUrl = "https://api.vietqr.io/img/PBVN.png" },
            new() { Bin = "970421", ShortName = "VRB", FullName = "Ngân hàng Liên doanh Việt - Nga", LogoUrl = "https://api.vietqr.io/img/VRB.png" }
        };
    }
}
