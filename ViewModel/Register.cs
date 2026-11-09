using System.ComponentModel.DataAnnotations;

namespace WebPage.ViewModel
{
    public class RegisterModel
    {
        [Display(Name = "Họ và Tên")]
        [Required(ErrorMessage = "Vui lòng nhập họ và tên.")]
        public string FullName { get; set; } = "";

        [Display(Name = "Số Điện Thoại")]
        [Required(ErrorMessage = "Vui lòng nhập số điện thoại.")]
        [RegularExpression("^[0-9]{10,12}$", ErrorMessage = "Số điện thoại không hợp lệ, chỉ bao gồm 10-12 chữ số.")]
        public string Phone { get; set; } = "";

        [Display(Name = "Địa Chỉ")]
        [Required(ErrorMessage = "Vui lòng nhập địa chỉ.")]
        public string Address { get; set; } = "";

        [Display(Name = "Tên Tài Khoản")]
        [Required(ErrorMessage = "Vui lòng nhập tên tài khoản.")]
        [RegularExpression("^[a-zA-Z0-9]{4,12}$", ErrorMessage = "Tên tài khoản phải từ 4-12 ký tự, chỉ gồm chữ và số.")]
        public string UserName { get; set; } = "";

        [Display(Name = "Mật Khẩu")]
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu.")]
        [DataType(DataType.Password)]
        [RegularExpression("^[a-zA-Z0-9]{4,12}$", ErrorMessage = "Mật khẩu phải từ 4-12 ký tự, chỉ gồm chữ và số.")]
        public string Password { get; set; } = "";

        [Display(Name = "Xác Nhận Mật Khẩu")]
        [DataType(DataType.Password)]
        [Compare("Password", ErrorMessage = "Mật khẩu và xác nhận mật khẩu không khớp.")]
        [Required(ErrorMessage = "Vui lòng xác nhận lại mật khẩu.")]
        public string ConfirmPassword { get; set; } = "";

        [Display(Name = "Địa Chỉ Email")]
        [Required(ErrorMessage = "Vui lòng nhập địa chỉ email.")]
        [EmailAddress(ErrorMessage = "Địa chỉ email không hợp lệ.")]
        public string Email { get; set; } = "";

        [Display(Name = "Mã Bí Mật")]
        [Required(ErrorMessage = "Vui lòng nhập mã bí mật.")]
        [RegularExpression("^[a-zA-Z0-9]{4,24}$", ErrorMessage = "Mã bí mật phải từ 4-24 ký tự, chỉ gồm chữ và số.")]
        [DataType(DataType.Password)]
        public string AccountCode { get; set; } = "";

        [Display(Name = "Câu Hỏi Bảo Mật")]
        [Required(ErrorMessage = "Vui lòng chọn câu hỏi bảo mật.")]
        public string Question { get; set; } = "";

        [Display(Name = "Câu Trả Lời")]
        [Required(ErrorMessage = "Vui lòng nhập câu trả lời cho câu hỏi bảo mật.")]
        public string Answer { get; set; } = "";

        [Display(Name = "Mã Giới Thiệu")]
        public string? InviteCode { get; set; }

        [Display(Name = "Mã Xác Nhận")]
        [Required(ErrorMessage = "Vui lòng nhập mã xác nhận (Captcha).")]
        public string Scode { get; set; } = "";
    }
}
