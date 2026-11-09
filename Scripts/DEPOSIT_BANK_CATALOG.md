The deposit bank catalogue is compiled into the application, so displaying bank choices and checking webhook bank identities do not depend on a live bank-list API.

Refresh from the public sources with Node.js 18 or newer, using the actual retrieval date:

```powershell
node WebPage.Core/Scripts/update-deposit-bank-catalog.mjs 2026-11-08
```

The script validates the response and generates `Helper/DepositBankCatalog.cs`. Review changes and build before deployment. The primary source is [VietQR's documented bank API](https://www.vietqr.io/api-bank), at `https://api.vietqr.io/v2/banks`. Additional names are merged only when their BIN agrees with [SePay's public bank identifiers](https://vietqr.app/banks.json), as referenced by [SePay's QR documentation](https://developer.sepay.vn/vi/tien-ich-khac/tao-qr-code). No credentials are used.

`IsSupported` means the identifier is known to this snapshot. It does not mean a bank account has been linked to SePay, that the bank supports every SePay collection method, or that its webhook is configured. New receiving accounts must still be linked and selected in SePay. Check each bank's requirements for virtual accounts and transfer descriptions.

Matching accepts documented names, codes, BINs and aliases, ignoring letter case, punctuation and Vietnamese accents. Different banks never match; unknown identifiers and aliases shared by different BINs fail closed. For example, `IBK Bank` is ambiguous between the Hanoi and Ho Chi Minh City branches; use its branch-specific code or BIN.
