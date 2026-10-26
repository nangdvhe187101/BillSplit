using System.Security.Claims;
using BillSplit.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BillSplit.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class StatisticsController : ControllerBase
{
    private readonly IStatisticsService _statisticsService;

    public StatisticsController(IStatisticsService statisticsService)
    {
        _statisticsService = statisticsService;
    }

    private Guid GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(claim!);
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboardStats()
    {
        var userId = GetUserId();
        var stats = await _statisticsService.GetDashboardStatsAsync(userId);
        return Ok(stats);
    }
}
