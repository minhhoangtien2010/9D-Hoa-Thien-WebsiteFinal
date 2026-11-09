namespace WebPage.ViewModel
{
    public class DbTestViewModel
    {
        // NineDragons_Account (Unified Database)
        public string? ConnectionString { get; set; }
        public bool IsConnected { get; set; }
        public string? ServerVersion { get; set; }
        public string? Error { get; set; }

        // Tables: name -> row count (-1 = not found)
        public Dictionary<string, int> Tables { get; set; } = new();

        // Stored Procedures: name -> exists
        public Dictionary<string, bool> StoredProcedures { get; set; } = new();

        // Metadata
        public DateTime TestTime { get; set; }
    }
}
