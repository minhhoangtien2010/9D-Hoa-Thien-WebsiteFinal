using WebPage.MutilResources;
using System.ComponentModel.DataAnnotations;

namespace WebPage.ViewModel
{
    // Token: 0x02000057 RID: 87
    public class LoginModel
    {
        public string? ReturnUrl { get; set; }
        // Token: 0x1700018D RID: 397
        // (get) Token: 0x0600035E RID: 862 RVA: 0x0000DC39 File Offset: 0x0000BE39
        // (set) Token: 0x0600035F RID: 863 RVA: 0x0000DC41 File Offset: 0x0000BE41
        [RegularExpression("^[a-zA-Z0-9]{4,12}$", ErrorMessage = "Tài khoản từ 4-10 ký tự thường.")]
        [Display(Name = "Tên Tài Khoản")]
        [Required(ErrorMessage = "Vui lòng nhập tên tài khoản.")]
        public string UserName { get; set; }

        // Token: 0x1700018E RID: 398
        // (get) Token: 0x06000360 RID: 864 RVA: 0x0000DC4A File Offset: 0x0000BE4A
        // (set) Token: 0x06000361 RID: 865 RVA: 0x0000DC52 File Offset: 0x0000BE52
        [Required(ErrorMessage = "Nhập vào mật khẩu")]
        [DataType(DataType.Password)]
        [RegularExpression("^[a-zA-Z0-9]{4,12}$", ErrorMessage = "Mật khẩu từ 4-20 ký tự thường.")]
        [Display(Name = "Mật khẩu")]
        public string Password { get; set; }
    }
}
