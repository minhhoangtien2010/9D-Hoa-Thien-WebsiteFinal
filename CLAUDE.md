# WebPage.Core — Shared Razor Class Library

## Overview
ASP.NET Core 8.0 Razor Class Library (RCL) containing ALL shared code for the WebPage multi-server ecosystem. Server projects reference this and selectively enable features.

**Skill:** `9d-web`

## Technology Stack
- ASP.NET Core 8.0, C# 12
- Database: SQL Server via **Dapper** (stored procedures ONLY — no EF Core)
- Auth: Cookie-based authentication for the web portal
- Localization: Vietnamese (default) + English via `IStringLocalizer<SharedResource>`
- Email: MailKit

## Project Structure

```
WebPage.Core/
├── ServiceCollectionExtensions.cs  ← DI + middleware setup (entry point)
├── Controllers/                    ← Main controllers (always compiled)
│   ├── AccountController.cs        ← Login, Register, Email verify
│   ├── HomeController.cs           ← Homepage, ServerStatus, HealthCheck
│   ├── NewsController.cs           ← News listing/detail
│   ├── GameInfoController.cs       ← Lore, Factions
│   ├── LanguageController.cs       ← Culture switching
│   └── CaptchaController.cs        ← CAPTCHA validation
├── Features/                       ← Conditionally compiled controllers
│   ├── Ranking/RankingController.cs
│   ├── Giftcode/GiftcodeController.cs
│   ├── FeatureGuides/FeaturesController.cs
│   ├── Shop/ShopController.cs
│   ├── DepositMilestone/DepositMilestoneController.cs
│   ├── SpendingMilestone/SpendingMilestoneController.cs
│   ├── GiftBox/GiftBoxController.cs
│   └── LuckyWheel/LuckyWheelController.cs
├── Areas/Profile/                  ← Authenticated user area
│   └── Controllers/
│       ├── ProfileController.cs    ← User profile
│       ├── SettingsController.cs   ← Password change, email
│       └── AdminController.cs      ← Admin panel (news, config, users)
├── Services/                       ← Business logic (Dapper + SPs)
│   ├── IUserRepository / UserRepository        ← Auth + user data
│   ├── IAccountService / AccountService        ← Auth orchestration
│   ├── IGameRepository / GameRepository        ← Game data queries
│   ├── IEmailService / EmailService            ← SMTP via MailKit
│   └── IFeatureService / FeatureService        ← Runtime feature flags
├── ConfigurationModels/            ← Strongly-typed appsettings sections
│   ├── ServerIdentitySettings.cs   ← ServerId, ServerName, Domain
│   ├── ServerInfoSettings.cs       ← ExpRate, DropRate, OpenDate
│   ├── SmtpSettings.cs             ← Email SMTP config
│   └── ... (other config models)
├── Models/                         ← POCOs + DTOs
├── ViewModel/                      ← UI view models
├── Views/                          ← Razor templates
│   ├── Shared/                     ← Layouts, partials, navbar, footer
│   ├── Account/, Home/, News/, etc.
│   └── Areas/Profile/Views/Admin/  ← Admin management views
├── DataFiles/                      ← Embedded XML configs
└── wwwroot/                        ← Static assets (embedded in DLL)
```

## Feature System (Two Layers)

### Compile-time (MSBuild)
Feature controllers in `Features/` are **excluded** from Core compilation. Each server selectively includes them:
```xml
<!-- In server .csproj -->
<DefineConstants>FEATURE_RANKING;FEATURE_GIFTCODE</DefineConstants>
<Compile Include="..\WebPage.Core\Features\Ranking\**\*.cs" />
```

### Runtime (appsettings.json)
```csharp
if (_featureService.IsEnabled("Ranking")) { /* load data */ }
```
Features: `Ranking`, `Giftcode`, `News`, `FeatureGuides`, `ServerInfo`, `WeaponRefining`, `MapInfo`, `WeeklyActivities`, `BossSpawnTimer`, `Shop`, `DepositMilestone`, `SpendingMilestone`, `GiftBox`, `LuckyWheel`

### SQL schema
Chỉ một phần SP sống trong repo (`Database/*.sql`); phần còn lại chỉ có trên SQL Server thật.
Các file đã có: `setup-deposit-feature.sql` (nạp thẻ SePay),
`setup-deposit-milestone-v2.sql` (Mốc Nạp — bảng + toàn bộ SP, có cơ chế kỳ + mốc lặp lại),
`setup-giftbox-feature.sql`, `setup-luckywheel-feature.sql`.
Quy ước: bảng `Tbl_Web_<Feature>_<Entity>`, SP user `sp_Web_<Feature>_<Action>`,
SP admin `sp_Web_<Feature>_Admin_<Action>`; mọi `CREATE TABLE` bọc guard, mọi SP `DROP/CREATE`.
Feature nào tiêu xu phải `INSERT Tbl_Web_Shop_Purchases` (`PurchaseType`) để tính vào Mốc tiêu phí.

## Database Pattern — Dapper + Stored Procedures

```csharp
using var connection = new SqlConnection(_connectionString);
var parameters = new DynamicParameters();
parameters.Add("@username", username);
parameters.Add("@result", dbType: DbType.Int32, direction: ParameterDirection.Output);
await connection.ExecuteAsync("sp_Web_Login", parameters, commandType: CommandType.StoredProcedure);
```

**Key SPs:** `sp_Web_Login` (1=ok, 0=wrong pwd, -3=locked), `sp_Web_Register`, `sp_Web_ChangePassword`, `sp_Web_GetUserDetails`, `sp_GetLatestNews`, `sp_GetRankings`, `sp_RedeemGiftcode`

**Password handling:** Passwords sent as plain text to SPs which hash internally (MD5 via `CAST(@pwd AS VARCHAR(60))`).

## DI Registration (ServiceCollectionExtensions.cs)

| Service | Lifetime | Purpose |
|---------|----------|---------|
| `IUserRepository` | Scoped | Auth + user data (Dapper) |
| `IAccountService` | Scoped | Auth orchestration |
| `IGameRepository` | Scoped | Game data operations |
| `IEmailService` | Scoped | SMTP via MailKit |
| `IFeatureService` | Singleton | Runtime feature flags |

## Localization
- `@L["KeyName"]` via `IStringLocalizer<SharedResource>`
- Resource files: `Resources/SharedResource.resx`
- Culture: Vietnamese default, English fallback. Switch via `?culture=en` or cookie.
