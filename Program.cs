using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Runtime.Versioning;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

[assembly: SupportedOSPlatform("windows")]

// A maintenance executable only. It never runs as a public website endpoint.
return await Portable.RunAsync(args);

static class Portable
{
    private static readonly byte[] Aad = Encoding.UTF8.GetBytes("HOATHIEN-PORTABLE-SECRETS-V1");
    private static readonly string PrivateDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "HoaThienPortal");
    private static readonly (string Key, string PathKey, string DefaultFile)[] Secrets =
    [
        ("Telegram:BotToken", "Telegram:SecretFile", "telegram-token.dpapi"),
        ("SePaySettings:GatewayIpnSecret", "SePaySettings:IpnSecretFile", "sepay-ipn-secret.dpapi"),
        ("GoogleSheets:SigningKey", "GoogleSheets:SecretFile", "sheets-signing-key.dpapi")
    ];

    private sealed record Envelope(int Version, string CreatedUtc, string Nonce, string Ciphertext, string Tag);

    public static async Task<int> RunAsync(string[] args)
    {
        try
        {
            if (!OperatingSystem.IsWindows()) throw new InvalidOperationException("Cong cu nay chi ho tro Windows x64.");
            var command = args.FirstOrDefault() ?? "help";
            var root = Path.GetFullPath(Option(args, "--root") ?? AppContext.BaseDirectory);
            switch (command)
            {
                case "preflight": return await PreflightAsync(root);
                case "export-secrets": Export(root, Required(args, "--output"), Required(args, "--key-file")); return 0;
                case "import-secrets": Import(root, Required(args, "--input"), Option(args, "--key-file"), args.Contains("--replace")); return 0;
                case "prepare-media": PrepareMedia(root, Required(args, "--destination")); return 0;
                case "self-test": SelfTest(); return 0;
                default:
                    Console.WriteLine("Portal.Portable preflight | export-secrets --output FILE --key-file FILE | import-secrets --input FILE [--key-file FILE] [--replace] | prepare-media --destination RELEASE | self-test");
                    Console.WriteLine("Duong dan cau hinh: --root THU_MUC_CHUA_APPSETTINGS");
                    return command == "help" ? 0 : 2;
            }
        }
        catch (SqlException ex)
        {
            Console.Error.WriteLine($"Khong ket noi duoc SQL (ma {ex.Number}). Kiem tra quyen dang nhap, database, firewall va dia chi IP duoc phep; khong co mat khau nao duoc in ra.");
            return 1;
        }
        catch (CryptographicException)
        {
            Console.Error.WriteLine("Khong giai ma duoc. Kiem tra khoa di chuyen va file ma hoa; DPAPI chi doc duoc tren may da tao file.");
            return 1;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or InvalidOperationException or JsonException or FormatException)
        {
            // Do not echo exception.Message: configuration errors can contain secret values.
            Console.Error.WriteLine($"Khong hoan tat thao tac ({ex.GetType().Name}). Kiem tra duong dan, quyen truy cap, tham so va huong dan di chuyen.");
            return 1;
        }
    }

    private static string? Option(string[] args, string name)
    {
        var i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
    private static string Required(string[] args, string name) => Option(args, name) ?? throw new ArgumentException(name);
    private static IConfiguration Config(string root)
    {
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";
        return new ConfigurationBuilder().SetBasePath(root)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables().Build();
    }
    private static string SecretPath(IConfiguration config, string root, string pathKey, string defaultFile) =>
        Path.GetFullPath(config[pathKey] ?? Path.Combine(PrivateDirectory, defaultFile), root);
    private static string MediaPath(IConfiguration config, string root) =>
        Path.GetFullPath(config["MediaStorage:RootPath"] is { Length: > 0 } custom ? custom : Path.Combine("App_Data", "uploads"), root);

    private static async Task<int> PreflightAsync(string root)
    {
        var config = Config(root);
        var failed = false;
        if (!Environment.Is64BitOperatingSystem) throw new InvalidOperationException("Can Windows x64.");
        Console.WriteLine("Windows x64: OK");
        if (string.IsNullOrWhiteSpace(config.GetConnectionString("DefaultConnection")))
        {
            Console.WriteLine("SQL DefaultConnection: thieu cau hinh ket noi.");
            failed = true;
        }
        foreach (var entry in config.GetSection("ConnectionStrings").GetChildren())
        {
            if (string.IsNullOrWhiteSpace(entry.Value)) continue;
            try
            {
                var connection = new SqlConnectionStringBuilder(entry.Value) { ConnectTimeout = 8, Pooling = false };
                await using var sql = new SqlConnection(connection.ConnectionString);
                await sql.OpenAsync();
                await using var check = new SqlCommand("SELECT 1", sql) { CommandTimeout = 8 };
                await check.ExecuteScalarAsync();
                Console.WriteLine($"SQL {entry.Key}: OK");
            }
            catch (SqlException ex) { Console.WriteLine($"SQL {entry.Key}: LOI (ma {ex.Number}); kiem tra ket noi/quyen/firewall."); failed = true; }
        }
        var uploads = MediaPath(config, root);
        Directory.CreateDirectory(uploads);
        var probe = Path.Combine(uploads, $".write-check-{Guid.NewGuid():N}.tmp");
        try { await File.WriteAllTextAsync(probe, "write check"); Console.WriteLine("App_Data/uploads: co quyen ghi"); }
        finally { if (File.Exists(probe)) File.Delete(probe); }
        foreach (var entry in Secrets)
        {
            if (!string.IsNullOrWhiteSpace(config[entry.Key])) { Console.WriteLine($"{entry.Key}: da cau hinh tren may chu"); continue; }
            var path = SecretPath(config, root, entry.PathKey, entry.DefaultFile);
            if (!File.Exists(path))
            {
                Console.WriteLine(entry.Key == "Telegram:BotToken"
                    ? "Telegram:BotToken: chua nhap; chay NHAP_BI_MAT.cmd de chuyen token tu may cu."
                    : entry.Key == "GoogleSheets:SigningKey" ? "GoogleSheets:SigningKey: chua cau hinh; bao cao va CSV van dung duoc."
                    : "SePaySettings:GatewayIpnSecret: chua cau hinh; QR doc lap. Checkout can X-Secret-Key rieng tai Admin/Nap tu dong.");
                continue;
            }
            var clear = ProtectedData.Unprotect(await File.ReadAllBytesAsync(path), null, DataProtectionScope.LocalMachine);
            CryptographicOperations.ZeroMemory(clear);
            Console.WriteLine($"{entry.Key}: DPAPI doc duoc tren may nay");
        }
        return failed ? 1 : 0;
    }

    private static byte[] Protect(byte[] plaintext, byte[] key)
    {
        var nonce = RandomNumberGenerator.GetBytes(12);
        var encrypted = new byte[plaintext.Length];
        var tag = new byte[16];
        using var aes = new AesGcm(key, 16);
        aes.Encrypt(nonce, plaintext, encrypted, tag, Aad);
        return JsonSerializer.SerializeToUtf8Bytes(new Envelope(1, DateTime.UtcNow.ToString("O"), Convert.ToBase64String(nonce), Convert.ToBase64String(encrypted), Convert.ToBase64String(tag)));
    }
    private static byte[] Unprotect(byte[] envelope, byte[] key)
    {
        var value = JsonSerializer.Deserialize<Envelope>(envelope) ?? throw new JsonException();
        if (value.Version != 1) throw new InvalidOperationException("Phien ban khong ho tro.");
        var nonce = Convert.FromBase64String(value.Nonce);
        var encrypted = Convert.FromBase64String(value.Ciphertext);
        var tag = Convert.FromBase64String(value.Tag);
        if (nonce.Length != 12 || tag.Length != 16) throw new CryptographicException();
        var clear = new byte[encrypted.Length];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(nonce, encrypted, tag, clear, Aad);
        return clear;
    }
    private static void RestrictFile(string path)
    {
        var acl = new FileSecurity();
        acl.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        acl.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User!, FileSystemRights.FullControl, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null), FileSystemRights.FullControl, AccessControlType.Allow));
        new FileInfo(path).SetAccessControl(acl);
    }
    private static void EnsurePrivateDirectory(string path)
    {
        if (Directory.Exists(path)) return;
        Directory.CreateDirectory(path);
        var acl = new DirectorySecurity();
        acl.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        foreach (var sid in new[] { WindowsIdentity.GetCurrent().User!, new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null) })
            acl.AddAccessRule(new FileSystemAccessRule(sid, FileSystemRights.FullControl, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
        new DirectoryInfo(path).SetAccessControl(acl);
    }
    private static void Export(string root, string output, string keyFile)
    {
        var config = Config(root);
        var values = new Dictionary<string, string>();
        foreach (var entry in Secrets)
        {
            var configured = config[entry.Key];
            if (!string.IsNullOrWhiteSpace(configured)) { values[entry.Key] = configured; continue; }
            var path = SecretPath(config, root, entry.PathKey, entry.DefaultFile);
            if (!File.Exists(path)) continue;
            var clear = ProtectedData.Unprotect(File.ReadAllBytes(path), null, DataProtectionScope.LocalMachine);
            try { values[entry.Key] = Encoding.UTF8.GetString(clear); }
            finally { CryptographicOperations.ZeroMemory(clear); }
        }
        if (values.Count == 0) { Console.WriteLine("Khong co bi mat cuc bo can di chuyen."); return; }
        output = Path.GetFullPath(output);
        keyFile = Path.GetFullPath(keyFile);
        var outputDirectory = Path.GetDirectoryName(output)!;
        if (keyFile.StartsWith(outputDirectory.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Khoa phai luu tach thu muc goi di chuyen.");
        if (File.Exists(output)) throw new IOException("File dich da ton tai.");
        EnsurePrivateDirectory(Path.GetDirectoryName(keyFile)!);
        var key = File.Exists(keyFile) ? Convert.FromBase64String(File.ReadAllText(keyFile).Trim()) : RandomNumberGenerator.GetBytes(32);
        if (key.Length != 32) throw new CryptographicException();
        var plaintext = JsonSerializer.SerializeToUtf8Bytes(values);
        try
        {
            if (!File.Exists(keyFile)) File.WriteAllText(keyFile, Convert.ToBase64String(key), new UTF8Encoding(false));
            RestrictFile(keyFile);
            Directory.CreateDirectory(Path.GetDirectoryName(output)!);
            File.WriteAllBytes(output, Protect(plaintext, key));
            Console.WriteLine($"Da xuat {values.Count} bi mat ma hoa AES-256-GCM. Khoa nam RIENG tai file duoc chi dinh; khong gui khoa cung ZIP.");
        }
        finally { CryptographicOperations.ZeroMemory(key); CryptographicOperations.ZeroMemory(plaintext); values.Clear(); }
    }
    private static byte[] ReadKey(string? keyFile)
    {
        if (!string.IsNullOrWhiteSpace(keyFile)) return Convert.FromBase64String(File.ReadAllText(keyFile).Trim());
        Console.Write("Nhap khoa di chuyen (an ky tu): ");
        var text = new StringBuilder();
        ConsoleKeyInfo key;
        while ((key = Console.ReadKey(intercept: true)).Key != ConsoleKey.Enter)
        {
            if (key.Key == ConsoleKey.Backspace) { if (text.Length > 0) text.Length--; }
            else if (!char.IsControl(key.KeyChar)) text.Append(key.KeyChar);
        }
        Console.WriteLine();
        return Convert.FromBase64String(text.ToString().Trim());
    }
    private static void Import(string root, string input, string? keyFile, bool replace)
    {
        var config = Config(root);
        var key = ReadKey(keyFile);
        byte[] plaintext = [];
        try
        {
            if (key.Length != 32) throw new CryptographicException();
            plaintext = Unprotect(File.ReadAllBytes(input), key);
            var values = JsonSerializer.Deserialize<Dictionary<string, string>>(plaintext) ?? throw new JsonException();
            if (values.Count == 0 || values.Keys.Any(name => !Secrets.Any(s => s.Key == name))) throw new JsonException();
            var targets = new List<(string Path, byte[] Bytes)>();
            foreach (var entry in Secrets)
            {
                if (!values.TryGetValue(entry.Key, out var value) || string.IsNullOrWhiteSpace(value)) continue;
                var path = SecretPath(config, root, entry.PathKey, entry.DefaultFile);
                if (File.Exists(path) && !replace) throw new IOException("Bi mat da ton tai; chi ghi de khi co --replace.");
                var clear = Encoding.UTF8.GetBytes(value);
                try { targets.Add((path, ProtectedData.Protect(clear, null, DataProtectionScope.LocalMachine))); }
                finally { CryptographicOperations.ZeroMemory(clear); }
            }
            foreach (var target in targets)
            {
                EnsurePrivateDirectory(Path.GetDirectoryName(target.Path)!);
                if (File.Exists(target.Path))
                {
                    var backup = target.Path + ".bak-" + DateTime.UtcNow.ToString("yyyyMMddHHmmssfff");
                    File.Copy(target.Path, backup);
                    RestrictFile(backup);
                }
                File.WriteAllBytes(target.Path, target.Bytes);
                RestrictFile(target.Path);
            }
            Console.WriteLine($"Da nhap {targets.Count} bi mat va ma hoa DPAPI cho may Windows nay. Khong co token nao duoc in ra.");
        }
        finally { CryptographicOperations.ZeroMemory(key); CryptographicOperations.ZeroMemory(plaintext); }
    }
    private static void SelfTest()
    {
        var key = RandomNumberGenerator.GetBytes(32);
        var fake = Encoding.UTF8.GetBytes("fake-secret-for-local-crypto-test");
        var blob = Protect(fake, key);
        var restored = Unprotect(blob, key);
        if (!CryptographicOperations.FixedTimeEquals(fake, restored)) throw new CryptographicException();
        var wrongKey = RandomNumberGenerator.GetBytes(32);
        var rejected = false;
        try { Unprotect(blob, wrongKey); } catch (CryptographicException) { rejected = true; }
        if (!rejected) throw new CryptographicException();
        var dpapi = ProtectedData.Protect(fake, null, DataProtectionScope.LocalMachine);
        var local = ProtectedData.Unprotect(dpapi, null, DataProtectionScope.LocalMachine);
        if (!CryptographicOperations.FixedTimeEquals(fake, local)) throw new CryptographicException();
        foreach (var bytes in new[] { key, wrongKey, fake, restored, local }) CryptographicOperations.ZeroMemory(bytes);
        Console.WriteLine("PASS: AES-GCM roundtrip, wrong-key rejection, Windows DPAPI roundtrip. No real secrets used.");
    }
    private static void PrepareMedia(string root, string destination)
    {
        var config = Config(root);
        destination = Path.GetFullPath(destination);
        var target = Path.Combine(destination, "App_Data", "uploads");
        var source = MediaPath(config, root);
        Directory.CreateDirectory(target);
        var copied = CopyImages(source, target);
        // Preserve old image URLs even if the source app has never run its startup migration.
        foreach (var category in new[] { "News", "Shop", "GiftBox", "LuckyWheel" })
            copied += CopyImages(Path.Combine(root, "wwwroot", "images", category), Path.Combine(target, "legacy", category));
        var productionPath = Path.Combine(destination, "appsettings.Production.json");
        JsonObject settings = File.Exists(productionPath)
            ? JsonNode.Parse(File.ReadAllText(productionPath), documentOptions: new JsonDocumentOptions { CommentHandling = JsonCommentHandling.Skip, AllowTrailingCommas = true })?.AsObject() ?? new JsonObject()
            : new JsonObject();
        if (settings["MediaStorage"] is JsonObject media) media["RootPath"] = "App_Data/uploads";
        else settings["MediaStorage"] = new JsonObject { ["RootPath"] = "App_Data/uploads" };
        File.WriteAllText(productionPath, settings.ToJsonString(new JsonSerializerOptions { WriteIndented = true }), new UTF8Encoding(false));
        Console.WriteLine($"Media: da giu {copied} tep anh vat ly va cac URL legacy; ban publish dung App_Data/uploads tuong doi.");
    }
    private static int CopyImages(string source, string target)
    {
        Directory.CreateDirectory(target);
        if (!Directory.Exists(source)) return 0;
        source = Path.GetFullPath(source).TrimEnd(Path.DirectorySeparatorChar);
        target = Path.GetFullPath(target).TrimEnd(Path.DirectorySeparatorChar);
        if (target.Equals(source, StringComparison.OrdinalIgnoreCase) || target.StartsWith(source + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Thu muc sao chep khong duoc nam trong thu muc anh nguon.");
        var copied = 0;
        foreach (var file in Directory.EnumerateFiles(source, "*", new EnumerationOptions { RecurseSubdirectories = true, AttributesToSkip = FileAttributes.ReparsePoint, IgnoreInaccessible = false }))
        {
            var copy = Path.Combine(target, Path.GetRelativePath(source, file));
            Directory.CreateDirectory(Path.GetDirectoryName(copy)!);
            if (!File.Exists(copy)) { File.Copy(file, copy); copied++; }
        }
        return copied;
    }
}
