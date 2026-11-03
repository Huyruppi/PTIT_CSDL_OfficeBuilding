# Ban giao SQL Server - 18 bang BCNF

## Noi dung

- `01_CreateSchema.sql`: tao database `QLToaNha_BCNF`, 18 bang nghiep vu, 18 PK, 23 FK va cac UNIQUE/CHECK/DEFAULT phu hop tung cot.
- `02_InsertSeedData.sql`: nap du lieu mau tong hop vao ca 18 bang, trong mot transaction.
- `03_Validate.sql`: doi soat seed, 32 ca vi pham rang buoc, ca hop le/DEFAULT thanh toan, CHECKCONSTRAINTS va CHECKDB. Cac thay doi thu nghiem deu rollback.
- `04_BackupAndVerify.sql`: tao backup moi COPY_ONLY/CHECKSUM, VERIFYONLY, restore sang database rieng, CHECKDB va doi chieu schema/du lieu thanh toan. Khong dung REPLACE, INIT hoac xoa database.
- `05_UpgradeExistingDatabase.sql`: nang cap database da nap seed sang schema moi, giu nguyen MaHoaDon/MaChiTiet va cac dong hoa don.
- `06_ThongNhatQuyTac.sql`: <!-- TV6 sửa --> dong bo CHECK ngay cung ngay va don gia dich vu duong tren CSDL 18 bang da ton tai, khong tao bang moi.
- `BCNF_18_Bang.mmd`: so do ERD Mermaid cua 18 bang va 23 quan he FK.
- `06_TestUpgradePaths.ps1`: kiem thu tao moi, nang cap INT/view thieu cot thanh toan va restore/nang cap backup legacy trong database rieng; giu lai database kiem thu.
- `07_PackageHandover.ps1`: dong goi ZIP chi gom SQL, PowerShell, tai lieu, log va BAK; loai tru MDF/NDF/LDF dang duoc SQL Server giu mo; kiem tra SHA256 tung file trong ZIP.
- `QLToaNha_BCNF_Seed_202608_202609_Updated_20261030_7981548AD2AB417CB5B6220CD8E12B3B.bak`: backup ban giao moi nhat ngay 30/10/2026, da VERIFYONLY va restore kiem chung, gom du 3 cot thanh toan va CHECK.
- `Upgrade_Result.txt`, `Validation_Result.txt`, `Backup_Verification_Result.txt`, `Upgrade_Paths_Result.txt`: ket qua kiem thu thuc te. Log Upgrade_Paths ngay 30/10 xac nhan ca ba duong tao moi/INT/legacy deu PASS, giu nguyen ID/noi dung hoa don va lich su thanh toan khi chay lap.

Nguon doi chieu: tai lieu `Phan_5_Ban_giao_Luoc_do_BCNF_cho_TV3_SQL_va_TV7_Phan_tan.docx` trong thu muc CSDL. Khong dung luoc do cu cua ung dung office-building-management.

## Chay tu dau

Can SQL Server, sqlcmd va tai khoan co quyen CREATE DATABASE. Seed chi chap nhan database rong. DDL tu choi neu da co bang, khong ghi de du lieu cu.

Chay tu thu muc goc workspace:

```powershell
sqlcmd -S '.\SQLEXPRESS' -E -C -b -i '.\CSDL\BCNF_BanGiao\01_CreateSchema.sql'
sqlcmd -S '.\SQLEXPRESS' -E -C -b -i '.\CSDL\BCNF_BanGiao\02_InsertSeedData.sql'
sqlcmd -S '.\SQLEXPRESS' -E -C -b -i '.\CSDL\BCNF_BanGiao\03_Validate.sql'
```

Trong SSMS, mo va Execute tung file theo thu tu 01, 02, 03. Khong chay lai seed tren database da co du lieu. Neu doi ten database, doi nhat quan ten trong cac file SQL.

<!-- TV6 sửa: 05 xử lý cấu trúc hóa đơn cũ, 06 xử lý quy tắc ngày/giá của schema thống nhất. -->
Neu database `QLToaNha_BCNF` da duoc tao theo phien ban cu, khong chay lai 01 hoac 02. Sau khi sao luu, chay `05_UpgradeExistingDatabase.sql` neu can nang cap ID/view/cot thanh toan, sau do `06_ThongNhatQuyTac.sql` de dong bo bon CHECK ngay va gia; chay 03 tren ban test truoc TV5. Migration 05 bao toan ID/dong hoa don va lich su thanh toan; migration 06 dung neu gia dich vu hien tai <= 0, can xu ly du lieu truoc.

De kiem thu hoi quy ca ba duong, chay task VS Code `BCNF: Test fresh and legacy upgrade paths` hoac `06_TestUpgradePaths.ps1` tu PowerShell. Script can quyen CREATE/RESTORE DATABASE, dung backup goc `CSDL/QLToaNha_BCNF_Seed_202608_202609.bak`, tao ten database rieng, khong ghi de database nguon. Moi database test duoc giu lai de doi chieu va chi xoa khi chu dong duoc phep.

File MDF/LDF cua cac lan kiem thu moi duoc dat trong thu muc data/log mac dinh cua SQL Server, khong dat trong thu muc ban giao. Cac file BCNF_TestLegacy*.mdf/.ldf con lai tu lan test cu dang duoc SQL Server su dung: khong xoa, doi ten hoac nen truc tiep chung voi bo ban giao. Can gui backup .bak, khong can gui cac file database dang mo.

## Dong goi ban giao

Chay `07_PackageHandover.ps1` bang PowerShell de tao `CSDL/BCNF_BanGiao_<thoi_gian>.zip`. Giai nen se co thu muc BCNF_BanGiao voi du file can thiet, khong co MDF/NDF/LDF hoac archive long nhau. Script khong ghi de ZIP cu va kiem tra SHA256 tung file sau khi nen. ZIP mo duoc bang WinRAR/7-Zip; khong can quyen Administrator hay dung SQL Server.

## Du lieu mau

Du lieu gia lap, khong phai thong tin doanh nghiep/nhan su that. MST chi duoc kiem tra dinh dang, khong xac nhan dang ky hay checksum MST. Gia/nguong phi la gia dinh minh hoa, can nhom duyet truoc khi dung nghiep vu that.

| Thanh phan | So dong |
| --- | ---: |
| ThamSo / ViTri / LoaiDichVu / BacCongViec | 5 / 2 / 3 / 3 |
| ToaNha / VanPhong / CongTy / HopDongThue | 3 / 12 / 6 / 12 |
| NhanVienCongTy / DichVu / SuDungDichVu | 60 / 9 / 18 |
| ChiTietSuDungNV | 7.320 |
| NhanVienToaNha / PhanCongNVTN / LuongThang | 9 / 18 / 18 |
| HoaDonThang / ChiTietHoaDon / ChiPhiVanHanh | 12 / 60 / 18 |

Khoang log: 01/08/2026 den het 30/09/2026, 61 ngay, gom ca cuoi tuan (gia dinh toa nha hoat dong hang ngay). Moi ngay, moi nhan vien co mot luot an va mot luot gui xe: 60 x 61 x 2 = 7.320 log.

- Thang 8: 3.720 log. Thang 9: 3.600 log.
- Tien dich vu theo luot: 146.400.000 VND, doi chieu tu log sang hoa don.
- Tien thue: 552.000.000 VND. Dich vu thang: 27.000.000 VND.
- Tong hoa don: 725.400.000 VND. Tong luong + thuong: 208.137.000 VND.
- Seed tao moi: 6 hoa don thang 8 da thanh toan, ngay thu = NgayLap + 5 ngay, NguoiThu = 'Thu ngan mau'; 6 hoa don thang 9 chua thanh toan nhan DEFAULT/NULL. Nang cap database hien co khong tu danh dau hoa don da thu; vi vay trang thai nguon/backup co the khac seed tao moi ma van dung nghiep vu va tong tien.
- Phi thang = gia co ban x (1 + ty le x (so buoc vuot nguoi + so buoc vuot dien tich)); so buoc lam tron len. Day la gia dinh seed, khong phai engine tinh phi theo bien dong giua thang.

## Quy uoc rang buoc

- Giua nguyen ten 18 bang, cac PK ghep va 23 FK, gom FK tu tham chieu MaQuanLy va FK ghep LuongThang -> PhanCongNVTN.
- Dien tich > 0; SoLuot > 0. So nguoi duoc bieu dien boi tham so NGUONG_NGUOI/BUOC_NGUOI: so nguyen > 0, khong them cot thua vao luoc do BCNF.
- <!-- TV6 sửa --> NgayKetThuc/NgayNghiViec la NULL (chua ket thuc) hoac >= ngay bat dau/vao lam; khoang ngay bao gom ca hai dau.
- MST bat buoc va duy nhat: 10 chu so hoac 10 chu so + dau '-' + 3 chu so. Khong chap nhan chu cai/khoang trang.
- ChiTietHoaDon kiem tra XOR: dong thue chi co MaVanPhong; dong dich vu chi co MaDichVu.
- SoTien hoa don duoc tinh trong view V_ChiTietHoaDon, khong la cot snapshot sua tay; DonGiaApDung luu don gia tai thoi diem lap dong. `MaHoaDon` dung `int IDENTITY(1,1)`.
- `HoaDonThang.TrangThai varchar(20) NOT NULL` mac dinh `CHUA_THANH_TOAN` qua `DF_HoaDon_TrangThai`; chi chap nhan `CHUA_THANH_TOAN` hoac `DA_THANH_TOAN`.
- `NgayThanhToan date NULL`, `NguoiThu nvarchar(100) NULL`. `CK_HoaDonThang_ThanhToan`: chua thanh toan thi ca ngay thu/nguoi thu phai NULL; da thanh toan thi ngay thu bat buoc va >= NgayLap. NguoiThu tuy chon khi da thu, nhung neu cung cap thi khong duoc rong/toan dau cach. NguoiThu la ten nguoi thu tai thoi diem ghi nhan, khong them FK, giu nguyen 23 FK.
- <!-- TV6 sửa --> Procedure thu tien TV4 ghi TrangThai, NgayThanhToan va NguoiThu trong cung mot UPDATE/transaction; chi ho tro thu du mot lan, khong co so quy/phieu thu doc lap.
- Khong them FK vao bang danh muc goc; khong ep UNIQUE hoac DEFAULT vo nghia len moi cot. Chi khai bao NULL cho thuoc tinh tuy chon.
- Khong CASCADE DELETE/UPDATE; cac tham chieu mac dinh NO ACTION de bao ve lich su.

Pham vi bo nay la DDL, seed, kiem thu va backup theo yeu cau. Cac trigger TG1-TG9 va 4 view bao cao trong tai lieu Word chua duoc trien khai. Cac quy tac lien bang (chong lich, cung toa nha, so tang, dong bang gia lich su) duoc doi soat tren seed boi 03, nhung chua duoc cuong che cho moi thao tac ghi tuong lai. CHECK khong thay the duoc cac trigger nay.

## Backup va restore

Backup ban giao tao bang SQL Server 2025 Express 17.0.1000.7. Can SQL Server 2025 hoac phien ban moi hon de restore; khong the restore xuong SQL Server 2022/2019. Tren ban cu, dung DDL + seed (chua kiem thu truc tiep tren cac phien ban cu).

File `QLToaNha_BCNF_Seed_202608_202609_Updated_20261030_7981548AD2AB417CB5B6220CD8E12B3B.bak` da duoc VERIFYONLY/CHECKSUM va restore vao `QLToaNha_BCNF_RestoreCheck_7981548AD2AB417CB5B6220CD8E12B3B`, du 18 bang, 23 FK, 7.320 log. CHECKDB tren database nguon va ban restore deu thanh cong. Log 04 xac nhan cot TrangThai/NgayThanhToan/NguoiThu, DEFAULT, CHECK trusted va doi chieu du lieu thanh toan hai chieu voi nguon. Database restore-check duoc giu lai lam bang chung; cac database kiem thu cu khac khong bi thay doi. Backup ngay 28/10 va 29/10 la phien ban truoc, khong dung thay cho ban 30/10.

Trong SSMS: Databases > Restore Database > Device > chon file .bak > doi ten database dich neu ten da ton tai > Files > sua duong dan data/log theo may dich > OK. Khong chon Overwrite neu khong chu dong thay the database cu. Tai khoan dich vu SQL Server phai doc duoc file .bak.

Co the xem logical file truoc khi restore:

```sql
RESTORE FILELISTONLY FROM DISK = N'E:\Copilot\CSDL\BCNF_BanGiao\QLToaNha_BCNF_Seed_202608_202609_Updated_20261030_7981548AD2AB417CB5B6220CD8E12B3B.bak';
RESTORE VERIFYONLY FROM DISK = N'E:\Copilot\CSDL\BCNF_BanGiao\QLToaNha_BCNF_Seed_202608_202609_Updated_20261030_7981548AD2AB417CB5B6220CD8E12B3B.bak' WITH CHECKSUM;
```

04 dang ghi backup truc tiep vao `E:\Copilot\CSDL\BCNF_BanGiao`; tai khoan dich vu SQL Server can quyen ghi vao thu muc nay. Khi chay tren may khac, sua `@BackupDirectory` trong script sang thu muc ma dich vu SQL Server co quyen ghi. Moi lan chay tao ten file va database restore-check rieng, khong ghi de ban cu.

## Database Diagram SSMS

`BCNF_18_Bang.mmd` la so do ERD nguon, gom du 18 bang va 23 FK. De tao ban native trong SSMS: ket noi database `QLToaNha_BCNF` > Database Diagrams > New Database Diagram > dong y cai support objects neu duoc hoi > chon du 18 bang > Add > Close > sap xep va Save thanh `BCNF_18_Bang`.

SSMS co the them bang ho tro dbo.sysdiagrams; day khong phai bang nghiep vu thu 19. 03_Validate.sql loai tru bang ho tro nay khi dem 18 bang/PK.
