using System.Security.Claims;
using BillSplit.Application.DTOs;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DebtsController : ControllerBase
{
    private readonly IDebtService _debtService;

    public DebtsController(IDebtService debtService)
    {
        _debtService = debtService;
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(idClaim!);
    }

    [HttpPost("split")]
    public async Task<IActionResult> SplitExpense([FromBody] SplitExpenseRequestDto request)
    {
        var userId = GetCurrentUserId();
        var (success, message, debts) = await _debtService.SplitExpenseAsync(userId, request);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message, debts });
    }

    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary()
    {
        var userId = GetCurrentUserId();
        var summary = await _debtService.GetNetBalanceSummaryAsync(userId);
        return Ok(summary);
    }

    [HttpGet]
    public async Task<IActionResult> GetDebts([FromQuery] string? status, [FromQuery] bool asCreditor = true)
    {
        var userId = GetCurrentUserId();
        var debts = await _debtService.GetDebtsAsync(userId, status, asCreditor);
        return Ok(debts);
    }

    [HttpPost("auto-settle")]
    public async Task<IActionResult> AutoSettle([FromBody] AutoSettleRequestDto request)
    {
        var userId = GetCurrentUserId();
        var (success, message, settledDebt) = await _debtService.AutoSettleByMessageAsync(userId, request);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message, settledDebt });
    }

    [HttpPost("{id}/manual-settle")]
    public async Task<IActionResult> ManualSettle(Guid id)
    {
        var userId = GetCurrentUserId();
        var (success, message) = await _debtService.ManualSettleAsync(userId, id);
        if (!success)
        {
            return BadRequest(new { message });
        }
        return Ok(new { message });
    }
}
