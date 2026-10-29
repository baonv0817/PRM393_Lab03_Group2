// Dữ liệu mẫu theo docs/data-model.md mục 8. Thuần dữ liệu, không gọi Firebase, nên dễ đọc và sửa.

// Giờ ra chơi 15 phút giữa hai slot học, giờ Việt Nam (HH:mm). Khung 10:15 khớp banner Combo Giờ Vàng
// ở Trang chủ; chỉnh các khung khác theo lịch học thật của nhóm.
export const BREAK_STARTS = ['08:45', '10:15', '13:15', '14:45'];
export const SLOT_MINUTES = 15;
export const SLOT_CAPACITY = 15;
export const SLOT_DAYS = 7; // số ngày tới có slot (bỏ thứ Bảy, Chủ nhật)

export const KIOSKS = [
  { id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', location: 'Campus Q9, tầng 2', open: true, waitMinutes: 6, openTime: '06:30', closeTime: '17:00' },
  { id: 'q9-t4', name: 'Kiosk Q9 · Tầng 4', location: 'Campus Q9, tầng 4', open: true, waitMinutes: 10, openTime: '06:30', closeTime: '17:00' },
  {
    id: 'nvh-t1', name: 'Nhà văn hóa SV · Tầng 1', location: 'Nhà văn hóa sinh viên, tầng 1', open: false, waitMinutes: 0,
    openTime: '07:00', closeTime: '16:00', notice: 'Kiosk tạm đóng, mời bạn chọn Kiosk Q9.',
  },
];

// Mỗi kiosk bán các món dưới đây (kiosk đóng cửa chỉ bán một phần). `soldOut` để thử S22, K09.
const MENU = [
  { slug: 'tacos-bo', name: 'Combo Tacos Bò Phô Mai', category: 'Tacos', priceVnd: 39000, prepMinutes: 4, description: 'Hai bánh tacos bò, phô mai, kèm nước ngọt.' },
  { slug: 'tacos-ga', name: 'Tacos Gà Giòn Sốt Cay', category: 'Tacos', priceVnd: 35000, prepMinutes: 4, description: 'Gà giòn, sốt cay, rau tươi.', soldOutAt: ['q9-t2'] },
  { slug: 'mi-tron-ga', name: 'Mì Trộn Gà Cay Hàn Quốc', category: 'Mì trộn', priceVnd: 35000, prepMinutes: 5, description: 'Mì trộn sốt cay, gà xé, trứng.' },
  { slug: 'mi-tron-bo', name: 'Mì Trộn Bò Xào', category: 'Mì trộn', priceVnd: 38000, prepMinutes: 6, description: 'Mì trộn, bò xào hành.' },
  { slug: 'com-ga', name: 'Cơm Gà Teriyaki', category: 'Cơm', priceVnd: 42000, prepMinutes: 8, description: 'Cơm trắng, gà sốt teriyaki, rau củ.' },
  { slug: 'banh-mi', name: 'Bánh Mì Chả Lụa Trứng', category: 'Bánh mì', priceVnd: 22000, prepMinutes: 3, description: 'Bánh mì nóng, chả lụa, trứng ốp la.' },
  { slug: 'tra-dao', name: 'Trà Đào Chanh Sả', category: 'Đồ uống', priceVnd: 20000, prepMinutes: 2, description: 'Trà đào, chanh, sả, đá.' },
  { slug: 'tra-sua', name: 'Trà Sữa Trân Châu', category: 'Đồ uống', priceVnd: 25000, prepMinutes: 3, description: 'Trà sữa, trân châu đen.' },
  { slug: 'cafe-sua', name: 'Cà Phê Sữa Đá', category: 'Đồ uống', priceVnd: 18000, prepMinutes: 2, description: 'Cà phê phin, sữa đặc.' },
  { slug: 'khoai-chien', name: 'Khoai Tây Chiên', category: 'Ăn vặt', priceVnd: 22000, prepMinutes: 4, description: 'Khoai tây chiên giòn, sốt tương cà.' },
];
const CLOSED_KIOSK_MENU = ['tacos-bo', 'tra-dao', 'cafe-sua', 'banh-mi', 'khoai-chien'];

// Bỏ dấu, chữ thường: dùng cho tìm kiếm theo đầu chuỗi (S28).
export function searchName(name) {
  return name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
}

export function menuItemsFor(kiosk) {
  return MENU.filter((m) => kiosk.open || CLOSED_KIOSK_MENU.includes(m.slug)).map((m) => ({
    id: `${kiosk.id}-${m.slug}`,
    kioskId: kiosk.id,
    name: m.name,
    searchName: searchName(m.name),
    description: m.description,
    priceVnd: m.priceVnd,
    category: m.category,
    prepMinutes: m.prepMinutes,
    soldOut: Boolean(m.soldOutAt?.includes(kiosk.id)),
    // Ảnh minh hoạ đóng gói trong app (nguồn: assets/images/menu/CREDITS.md). Khi seller tải ảnh
    // lên Cloud Storage thì thay bằng link https của ảnh đó.
    imageUrl: `assets/images/menu/${m.slug}.jpg`,
  }));
}

export const VOUCHERS = [
  { code: 'BBSTUDENT', title: 'Giảm 10K cho sinh viên', discountVnd: 10000, minOrderVnd: 40000, expiresAt: '2100-01-01', active: true },
  { code: 'GIOVANG', title: 'Combo Giờ Vàng giảm 15%, tối đa 15K', discountVnd: 0, percent: 15, maxDiscountVnd: 15000, minOrderVnd: 30000, expiresAt: '2100-01-01', active: true },
  { code: 'BB20', title: 'Mã đã hết hạn (để thử báo lỗi)', discountVnd: 20000, minOrderVnd: 0, expiresAt: '2020-01-01', active: true },
];
