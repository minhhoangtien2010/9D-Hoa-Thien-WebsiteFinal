namespace WebPage.ViewModel;

public record ProfileMenuLink(string Controller, string Action, string Label, string Icon,
    string Area = "Profile", string Feature = "");
