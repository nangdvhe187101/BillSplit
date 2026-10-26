using System.Text;
using BillSplit.Application.Interfaces;
using BillSplit.Infrastructure.Data;
using BillSplit.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// 1. Cấu hình DbContext (Hỗ trợ SQLite cục bộ thuận tiện chạy demo hoặc SQL Server)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
                       ?? "Data Source=billsplit.db";

builder.Services.AddDbContext<AppDbContext>(options =>
{
    // Mặc định sử dụng SQLite để có thể chạy ngay trên mọi máy tính không cần cài đặt SQL Server
    options.UseSqlite(connectionString);
});

// 2. Đăng ký Dependency Injection cho các tầng Service
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<IStorageService, CloudflareR2StorageService>();
builder.Services.AddHostedService<ReceiptCleanupBackgroundService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IBankService, BankService>();
builder.Services.AddScoped<IFriendService, FriendService>();
builder.Services.AddScoped<IGroupService, GroupService>();
builder.Services.AddScoped<IDebtService, DebtService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IStatisticsService, StatisticsService>();

// 3. Cấu hình Xác thực JWT Bearer Token
// Secret BẮT BUỘC phải được cấu hình qua User Secrets / biến môi trường (Jwt:Secret),
// không hardcode trong source code để tránh ai đọc được code cũng tự ký được token giả.
var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException(
        "Thiếu cấu hình 'Jwt:Secret'. Hãy đặt qua biến môi trường Jwt__Secret hoặc " +
        "chạy: dotnet user-secrets set \"Jwt:Secret\" \"<chuỗi ngẫu nhiên ít nhất 32 ký tự>\"");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "BillSplitApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "BillSplitApp";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
    };
});

builder.Services.AddAuthorization();

// 4. Cấu hình Controllers & CORS
builder.Services.AddControllers();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// 5. Cấu hình Swagger / OpenAPI với hỗ trợ gõ Bearer Token
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "BillSplit Auto API",
        Version = "v1",
        Description = "RESTful API cho ứng dụng chia tiền tự động môn PRM"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Nhập JWT Token theo định dạng: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// 6. Tự động khởi tạo Database và nạp dữ liệu mẫu ngân hàng khi ứng dụng khởi động
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await dbContext.Database.EnsureCreatedAsync();

    var bankService = scope.ServiceProvider.GetRequiredService<IBankService>();
    await bankService.SeedDefaultBanksAsync();
}

// 7. Cấu hình HTTP Pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
