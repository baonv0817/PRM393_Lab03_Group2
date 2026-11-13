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

// Tuỳ chọn mẫu (docs/data-model.md, `optionGroups`): khách chọn trước khi thêm món (size, topping, mức cay…).
// Mỗi nhóm: id, name, required, maxChoices (1 = chọn một, >1 = chọn tối đa N), choices[{id, name, extraVnd}].
const group = (id, name, required, maxChoices, choices) => ({
  id, name, required, maxChoices, choices: choices.map(([cid, cname, extraVnd = 0]) => ({ id: cid, name: cname, extraVnd })),
});
const SIZE = group('size', 'Size', true, 1, [['s', 'Size S'], ['m', 'Size M', 5000], ['l', 'Size L', 10000]]);
const SUGAR = group('sugar', 'Mức đường', true, 1, [['100', '100% đường'], ['70', '70% đường'], ['50', '50% đường'], ['30', '30% đường']]);
const SPICE = group('spice', 'Mức cay', true, 1, [['none', 'Không cay'], ['mild', 'Cay vừa'], ['hot', 'Cay nhiều'], ['xhot', 'Siêu cay', 0]]);

const OPTIONS = {
  'tra-dao': [SIZE, SUGAR, group('topping', 'Topping', false, 2, [['thach', 'Thạch dừa', 5000], ['chia', 'Hạt chia', 4000], ['dao', 'Thêm đào miếng', 7000]])],
  'tra-sua': [SIZE, SUGAR, group('topping', 'Topping', false, 3, [['tc', 'Trân châu đen', 5000], ['thach', 'Thạch', 5000], ['pudding', 'Pudding', 7000], ['kem', 'Kem cheese', 10000]])],
  'cafe-sua': [SIZE, SUGAR, group('extra', 'Thêm', false, 2, [['shot', 'Thêm 1 shot cà phê', 8000], ['sua', 'Thêm sữa đặc', 3000]])],
  'mi-tron-ga': [SPICE, group('extra', 'Thêm', false, 2, [['trung', 'Thêm trứng', 6000], ['ga', 'Thêm gà', 15000], ['pho-mai', 'Thêm phô mai', 7000]])],
  'mi-tron-bo': [SPICE, group('extra', 'Thêm', false, 2, [['trung', 'Thêm trứng', 6000], ['bo', 'Thêm bò', 15000]])],
  'com-ga': [group('rice', 'Phần cơm', true, 1, [['thuong', 'Cơm thường'], ['them', 'Thêm cơm', 5000]]), group('extra', 'Thêm', false, 2, [['trung', 'Trứng ốp la', 6000], ['rau', 'Thêm rau củ', 4000]])],
  'tacos-bo': [group('extra', 'Thêm', false, 2, [['pho-mai', 'Thêm phô mai', 7000], ['sot', 'Thêm sốt cay', 0]])],
  'banh-mi': [group('extra', 'Thêm', false, 3, [['trung', 'Thêm trứng', 5000], ['cha', 'Thêm chả lụa', 6000], ['pate', 'Thêm pate', 4000]])],
  'khoai-chien': [group('size', 'Size', true, 1, [['s', 'Phần nhỏ'], ['l', 'Phần lớn', 8000]]), group('sauce', 'Sốt', false, 1, [['cheese', 'Phô mai bột', 3000], ['bbq', 'BBQ', 0]])],
};

// Mỗi kiosk bán các món dưới đây (kiosk đóng cửa chỉ bán một phần). `soldOut` để thử S22, K09.
const MENU = [
  { slug: 'tacos-bo', name: 'Combo Tacos Bò Phô Mai', category: 'food', priceVnd: 39000, prepMinutes: 4, description: 'Hai bánh tacos bò, phô mai, kèm nước ngọt.' },
  { slug: 'tacos-ga', name: 'Tacos Gà Giòn Sốt Cay', category: 'food', priceVnd: 35000, prepMinutes: 4, description: 'Gà giòn, sốt cay, rau tươi.', soldOutAt: ['q9-t2'] },
  { slug: 'mi-tron-ga', name: 'Mì Trộn Gà Cay Hàn Quốc', category: 'food', priceVnd: 35000, prepMinutes: 5, description: 'Mì trộn sốt cay, gà xé, trứng.' },
  { slug: 'mi-tron-bo', name: 'Mì Trộn Bò Xào', category: 'food', priceVnd: 38000, prepMinutes: 6, description: 'Mì trộn, bò xào hành.' },
  { slug: 'com-ga', name: 'Cơm Gà Teriyaki', category: 'food', priceVnd: 42000, prepMinutes: 8, description: 'Cơm trắng, gà sốt teriyaki, rau củ.' },
  { slug: 'banh-mi', name: 'Bánh Mì Chả Lụa Trứng', category: 'food', priceVnd: 22000, prepMinutes: 3, description: 'Bánh mì nóng, chả lụa, trứng ốp la.' },
  { slug: 'tra-dao', name: 'Trà Đào Chanh Sả', category: 'drink', priceVnd: 20000, prepMinutes: 2, description: 'Trà đào, chanh, sả, đá.' },
  { slug: 'tra-sua', name: 'Trà Sữa Trân Châu', category: 'drink', priceVnd: 25000, prepMinutes: 3, description: 'Trà sữa, trân châu đen.' },
  { slug: 'cafe-sua', name: 'Cà Phê Sữa Đá', category: 'drink', priceVnd: 18000, prepMinutes: 2, description: 'Cà phê phin, sữa đặc.' },
  { slug: 'khoai-chien', name: 'Khoai Tây Chiên', category: 'food', priceVnd: 22000, prepMinutes: 4, description: 'Khoai tây chiên giòn, sốt tương cà.' },
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
    dishId: m.slug,
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
