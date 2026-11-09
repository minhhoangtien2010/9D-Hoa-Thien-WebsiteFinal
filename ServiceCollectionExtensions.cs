using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Localization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Net.Http.Headers;
using System.Globalization;
using System.IO.Compression;
using System.Threading.RateLimiting;
using WebPage.ConfigurationModels;
using WebPage.Services;

namespace WebPage
{
    public static class ServiceCollectionExtensions
    {
        /// <summary>
        /// Register all core services shared across all server projects.
        /// </summary>
        public static IServiceCollection AddCoreServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddLocalization();

            services.AddControllersWithViews()
                .AddViewLocalization()
                .AddDataAnnotationsLocalization();

            // Configuration models
            services.Configure<MyApplicationSettings>(configuration.GetSection("MyApplicationSettings"));
            services.Configure<CCPropertiesSettings>(configuration.GetSection("CCPropertiesSettings"));
            services.Configure<SmtpSettings>(configuration.GetSection("SmtpSettings"));
            services.Configure<ServerIdentitySettings>(configuration.GetSection("ServerIdentity"));

            // Configurable game sections (used by ThanhLong and other servers when enabled)
            services.Configure<ServerInfoSettings>(configuration.GetSection("ServerInfoSettings"));
            services.Configure<WeaponRefiningSettings>(configuration.GetSection("WeaponRefiningSettings"));
            services.Configure<ClothRefiningSettings>(configuration.GetSection("ClothRefiningSettings"));
            services.Configure<MapInfoSettings>(configuration.GetSection("MapInfoSettings"));
            services.Configure<WeeklyActivitiesSettings>(configuration.GetSection("WeeklyActivitiesSettings"));
            services.Configure<DownloadSettings>(configuration.GetSection("DownloadSettings"));
            services.Configure<SlideShowSettings>(configuration.GetSection("SlideShowSettings"));
            services.Configure<SePaySettings>(configuration.GetSection("SePaySettings"));

            services.AddHttpContextAccessor();

            // Authentication (Cookie for web)
            services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
                .AddCookie(options =>
                {
                    options.LoginPath = "/Account/Login";
                    options.LogoutPath = "/Account/Logout";
                    options.AccessDeniedPath = "/Account/Login";
                    options.ExpireTimeSpan = TimeSpan.FromHours(24);
                    options.SlidingExpiration = true;
                });

            services.AddSession(options =>
            {
                options.IdleTimeout = TimeSpan.FromMinutes(30);
                options.Cookie.HttpOnly = true;
                options.Cookie.IsEssential = true;
            });

            // Repositories & Services
            services.AddScoped<IUserRepository, UserRepository>();
            services.AddScoped<IAccountService, AccountService>();
            services.AddScoped<IGameRepository, GameRepository>();
            services.AddScoped<PortalRepository>();
            services.AddScoped<DepositSettingsRepository>();
            services.AddScoped<GameVisibilityRepository>();
            services.AddScoped<DepositCheckoutService>();
            services.AddScoped<DepositConfirmationRepository>();
            services.AddSingleton<PublicMediaStorage>();
            services.AddSingleton<DepositIpnSecretStore>();
            services.AddScoped<AboutContentRepository>();
            services.AddScoped<NewsCategoryRepository>();
            services.AddScoped<TelegramNotificationRepository>();
            services.AddScoped<CharacterRenameRepository>();
            services.AddScoped<DepositReportRepository>();
            services.AddSingleton<SheetSecretStore>();
            services.AddSingleton<DepositSheetClient>();
            services.AddHostedService<DepositReportWorker>();
            services.AddSingleton<TelegramSecretStore>();
            services.AddSingleton<TelegramBotClient>();
            services.AddHostedService<TelegramNotificationWorker>();
            services.AddScoped<ShopImageService>();
            services.AddScoped<IEmailService, EmailService>();

            // Feature service (runtime feature flags from appsettings)
            services.AddSingleton<IFeatureService, FeatureService>();

            // SePay payment gateway (Deposit feature)
            services.AddSingleton<SePayGatewayService>();

            // Shop delivery service (CIS_DB integration)
            services.AddScoped<IShopDeliveryService, ShopDeliveryService>();

            // Spending milestone orchestrator (auto-grant after shop purchase)
            services.AddScoped<ISpendingMilestoneService, SpendingMilestoneService>();

            // Response compression (Brotli + Gzip)
            services.AddResponseCompression(options =>
            {
                options.EnableForHttps = true;
                options.Providers.Add<BrotliCompressionProvider>();
                options.Providers.Add<GzipCompressionProvider>();
                options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(new[]
                {
                    "image/svg+xml",
                    "application/font-woff2",
                    "application/javascript",
                    "text/css"
                });
            });
            services.Configure<BrotliCompressionProviderOptions>(options =>
            {
                options.Level = CompressionLevel.Fastest;
            });
            services.Configure<GzipCompressionProviderOptions>(options =>
            {
                options.Level = CompressionLevel.SmallestSize;
            });

            // Rate limiting
            services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = 429;
                options.AddSlidingWindowLimiter("ShopPurchase", opt =>
                {
                    opt.Window = TimeSpan.FromSeconds(10);
                    opt.SegmentsPerWindow = 2;
                    opt.PermitLimit = 3;
                    opt.QueueLimit = 0;
                });
                options.AddSlidingWindowLimiter("GiftBoxOpen", opt =>
                {
                    opt.Window = TimeSpan.FromSeconds(10);
                    opt.SegmentsPerWindow = 2;
                    opt.PermitLimit = 10;
                    opt.QueueLimit = 0;
                });
                options.AddSlidingWindowLimiter("LuckyWheelSpin", opt =>
                {
                    opt.Window = TimeSpan.FromSeconds(10);
                    opt.SegmentsPerWindow = 2;
                    opt.PermitLimit = 10;
                    opt.QueueLimit = 0;
                });
            });

            return services;
        }

        /// <summary>
        /// Configure the core middleware pipeline shared across all server projects.
        /// </summary>
        public static WebApplication ConfigureCoreMiddleware(this WebApplication app)
        {
            if (!app.Environment.IsDevelopment())
            {
                app.UseExceptionHandler("/Home/Error");
                app.UseHsts();
            }

            app.UseStatusCodePagesWithReExecute("/Home/Error", "?statusCode={0}");

            // Response compression
            app.UseResponseCompression();

            // Security headers
            app.Use(async (context, next) =>
            {
                context.Response.Headers["X-Content-Type-Options"] = "nosniff";
                context.Response.Headers["X-Frame-Options"] = "SAMEORIGIN";
                context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
                context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
                await next();
            });

            // Skip HTTPS redirect for /.well-known/* (SSL DCV bots must access via plain HTTP to validate domain).
            app.UseWhen(
                context => !context.Request.Path.StartsWithSegments("/.well-known"),
                branch => branch.UseHttpsRedirection());

            // Static file cache headers:
            //   Development → no-cache (browser always re-validates, so CSS/JS edits appear immediately)
            //   Production  → 1 year immutable (safe because asp-append-version content-hashes the URL)
            var isDev = app.Environment.IsDevelopment();
            void SetCacheHeaders(StaticFileResponseContext ctx)
            {
                ctx.Context.Response.Headers[HeaderNames.CacheControl] = isDev
                    ? "no-cache, no-store, must-revalidate"
                    : "public, max-age=31536000, immutable";
            }

            // Serve static files from the Core RCL
            // Development: use physical wwwroot from Core project
            // Production: use embedded resources from Core DLL
            var coreWwwrootPath = Path.GetFullPath(
                Path.Combine(app.Environment.ContentRootPath, "..", "WebPage.Core", "wwwroot"));

            // Register Core files in WebRootFileProvider so asp-append-version can compute
            // content-hash fingerprints for Core CSS/JS. Without this, Core files get served
            // with immutable 1-year cache headers but no version hash in their URL — browsers
            // cache them forever and never detect changes after a rebuild.
            if (app.Environment.IsDevelopment() && Directory.Exists(coreWwwrootPath))
            {
                app.Environment.WebRootFileProvider = new CompositeFileProvider(
                    new PhysicalFileProvider(coreWwwrootPath),
                    app.Environment.WebRootFileProvider
                );
            }
            else
            {
                try
                {
                    var coreAssembly = typeof(ServiceCollectionExtensions).Assembly;
                    var coreEmbeddedForHashing = new ManifestEmbeddedFileProvider(coreAssembly, "wwwroot");
                    app.Environment.WebRootFileProvider = new CompositeFileProvider(
                        coreEmbeddedForHashing,
                        app.Environment.WebRootFileProvider
                    );
                }
                catch { }
            }

            if (app.Environment.IsDevelopment() && Directory.Exists(coreWwwrootPath))
            {
                var corePhysicalProvider = new PhysicalFileProvider(coreWwwrootPath);
                // Serve at root path (~/css/, ~/js/, ~/images/)
                app.UseStaticFiles(new StaticFileOptions
                {
                    FileProvider = corePhysicalProvider,
                    OnPrepareResponse = SetCacheHeaders
                });
                // Also serve at standard RCL content path (/_content/WebPage.Core/)
                app.UseStaticFiles(new StaticFileOptions
                {
                    FileProvider = corePhysicalProvider,
                    RequestPath = "/_content/WebPage.Core",
                    OnPrepareResponse = SetCacheHeaders
                });
            }

            // -----------------------------------------------------------------------
            // Static file pipeline:
            //
            //  DEVELOPMENT: skip all embedded DLL providers → every request hits
            //               the physical disk directly, so editing a file (logo,
            //               CSS, JS, image) is visible on the very next page load
            //               without a rebuild.
            //
            //  PRODUCTION:  serve from embedded DLLs (Core + server-specific)
            //               with 1-year immutable cache headers.
            // -----------------------------------------------------------------------

            var entryAssembly = System.Reflection.Assembly.GetEntryAssembly();

            if (!isDev)
            {
                // Server-specific embedded assets (images unique to each server variant).
                // Registered BEFORE Core so server files take priority over Core defaults.
                if (entryAssembly != null && entryAssembly != typeof(ServiceCollectionExtensions).Assembly)
                {
                    try
                    {
                        var serverEmbeddedProvider = new ManifestEmbeddedFileProvider(entryAssembly, "wwwroot");
                        app.UseStaticFiles(new StaticFileOptions
                        {
                            FileProvider = serverEmbeddedProvider,
                            OnPrepareResponse = SetCacheHeaders
                        });
                    }
                    catch
                    {
                        // Server has no embedded wwwroot manifest — skip
                    }
                }

                // Embedded static files from Core assembly (production fallback)
                try
                {
                    var coreAssembly = typeof(ServiceCollectionExtensions).Assembly;
                    var embeddedProvider = new ManifestEmbeddedFileProvider(coreAssembly, "wwwroot");
                    app.UseStaticFiles(new StaticFileOptions
                    {
                        FileProvider = embeddedProvider,
                        OnPrepareResponse = SetCacheHeaders
                    });
                    app.UseStaticFiles(new StaticFileOptions
                    {
                        FileProvider = embeddedProvider,
                        RequestPath = "/_content/WebPage.Core",
                        OnPrepareResponse = SetCacheHeaders
                    });
                }
                catch { }
            }

            // App's own wwwroot — physical files (.well-known, PATCH, images, etc.)
            // In development this is the primary source for ALL server-specific assets.
            app.UseStaticFiles(new StaticFileOptions
            {
                OnPrepareResponse = SetCacheHeaders
            });

            // Localization — vi (Vietnamese) default, en (English) supported
            var supportedCultures = new[] { new CultureInfo("vi"), new CultureInfo("en") };
            app.UseRequestLocalization(new RequestLocalizationOptions
            {
                DefaultRequestCulture = new RequestCulture("vi"),
                SupportedCultures = supportedCultures,
                SupportedUICultures = supportedCultures,
                RequestCultureProviders = new List<IRequestCultureProvider>
                {
                    new CookieRequestCultureProvider(),
                    new QueryStringRequestCultureProvider(),
                }
            });

            app.UseRouting();
            app.UseSession();

            // Rate limiting (before auth)
            app.UseRateLimiter();

            app.UseAuthentication();
            app.UseAuthorization();

            // Area routes
            app.MapControllerRoute(
                name: "areas",
                pattern: "{area:exists}/{controller=Profile}/{action=Index}/{id?}");

            // Default route
            app.MapControllerRoute(
                name: "default",
                pattern: "{controller=Home}/{action=Index}/{id?}");

            return app;
        }
    }
}
