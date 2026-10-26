using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BanksController : ControllerBase
{
    private readonly IBankService _bankService;

    public BanksController(IBankService bankService)
    {
        _bankService = bankService;
    }

    [HttpGet]
    public async Task<ActionResult<List<BankDto>>> GetBanks()
    {
        var banks = await _bankService.GetAllBanksAsync();
        return Ok(banks);
    }
}
