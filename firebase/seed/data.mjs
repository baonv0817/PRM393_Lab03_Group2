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

import { MENU, OPTIONS } from './ftacode-catalog.mjs';
const CLOSED_KIOSK_MENU = MENU.slice(0, 5).map(m => m.slug);

// Bỏ dấu, chữ thường: dùng cho tìm kiếm theo đầu chuỗi (S28).
export function searchName(name) {
  return name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
}

export function menuItemsFor(kiosk) {
  return MENU.filter((m) => kiosk.open || CLOSED_KIOSK_MENU.includes(m.slug)).map((m) => ({
    id: `${kiosk.id}-${m.slug}`,
    kioskId: kiosk.id,
    dishId: m.slug,
    name: m.name,
    searchName: searchName(m.name),
    description: m.description,
    priceVnd: m.priceVnd,
    category: m.category,
    prepMinutes: m.prepMinutes,
    soldOut: Boolean(m.soldOutAt?.includes(kiosk.id)),
    // Source product photos; an empty URL means the source has no photo.
    imageUrl: m.imageUrl,
    ...(OPTIONS[m.slug] ? { optionGroups: OPTIONS[m.slug] } : {}),
  }));
}

export const VOUCHERS = [
  { code: 'BBSTUDENT', title: 'Giảm 10K cho sinh viên', discount: { type: 'fixed', amountVnd: 10000 }, minOrderVnd: 40000, expiresAt: '2100-01-01', active: true },
  {
    code: 'GIOVANG', title: 'Combo Giờ Vàng giảm 15%, tối đa 15K', discount: { type: 'percent', percent: 15, maxVnd: 15000 },
    minOrderVnd: 30000, expiresAt: '2100-01-01', activeFrom: '10:15', activeTo: '10:30', active: true,
  },
  { code: 'COMBO5', title: 'Giảm 5K cho đơn từ 25K', discount: { type: 'fixed', amountVnd: 5000 }, minOrderVnd: 25000, expiresAt: '2100-01-01', active: true },
  { code: 'NEWBIE', title: 'Bạn mới giảm 20%, tối đa 12K', discount: { type: 'percent', percent: 20, maxVnd: 12000 }, minOrderVnd: 30000, expiresAt: '2100-01-01', active: true },
  { code: 'BB20', title: 'Mã đã hết hạn (để thử báo lỗi)', discount: { type: 'fixed', amountVnd: 20000 }, minOrderVnd: 0, expiresAt: '2020-01-01', active: true },
];

export { OPTIONS };
