using WebPage.Services;

using System.ComponentModel.DataAnnotations;

namespace WebPage.ViewModel
{
    public class ProfileViewModel
    {
        public string UserName { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public long Balance { get; set; }
        public DateTime MemberSince { get; set; }
        public List<CharacterInfoViewModel> Characters { get; set; } = new();
        public DailyCheckInStatePoco? DailyCheckIn { get; set; }
    }

    public class CharacterInfoViewModel
    {
        public string Name { get; set; } = string.Empty;
        public int Level { get; set; }
        public string Faction { get; set; } = string.Empty;
        public string Responsibility { get; set; } = string.Empty;
        public DateTime LastLogin { get; set; }
    }

    public class ChangePasswordViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại.")]
        public string CurrentPassword { get; set; } = string.Empty;
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới.")]
        public string NewPassword { get; set; } = string.Empty;
        [Required(ErrorMessage = "Vui lòng nhập lại mật khẩu mới.")]
        [Compare(nameof(NewPassword), ErrorMessage = "Hai mật khẩu mới chưa trùng nhau.")]
        public string ConfirmNewPassword { get; set; } = string.Empty;
    }

    public class TransactionViewModel
    {
        public int Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public int Amount { get; set; }
        public DateTime Date { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}
