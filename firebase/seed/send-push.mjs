// Gửi một thông báo đẩy (FCM) tới các thiết bị của một tài khoản, từ phía server bằng Admin SDK.
//
//   node send-push.mjs <email|uid> "<tiêu đề>" "<nội dung>" [--order=<mã đơn> --status=<trạng thái>]
//        [--dry-run] --project=<id> --yes
//
// Ví dụ: node send-push.mjs hanh@gmail.com "Đơn đã sẵn sàng" "Mời bạn tới quầy nhận món" --order=A-209 --status=ready --project=breakbite-1315b --yes
//
// Luồng (đây là điều cần giải thích khi bảo vệ):
//  1. App lấy token FCM của thiết bị (FirebaseMessaging.getToken) và ghi vào users/{uid}.fcmTokens (tối đa 5).
//  2. Script này (chạy ở máy có khoá service account, đóng vai "server") đọc các token đó trong Firestore.
//  3. Admin SDK gọi FCM HTTP v1 (messages:send) kèm token và payload; Google đẩy tới thiết bị.
//  4. App nhận ở 1 trong 3 trạng thái (đang mở, nền, đã đóng), lưu vào hộp thông báo và mở đúng màn khi chạm.
// --dry-run chỉ để FCM kiểm tra payload và token, không gửi thật. Token không còn hợp lệ bị xoá khỏi hồ sơ.
// Cần GOOGLE_APPLICATION_CREDENTIALS (khoá ngoài repo), như set-role.mjs. Emulator không có FCM.
import { connect } from './admin.mjs';

const argv = process.argv.slice(2);
const [target, title, body] = argv.filter((a) => !a.startsWith('--'));
const flag = (name) => argv.find((a) => a.startsWith(`--${name}=`))?.split('=').slice(1).join('=');
const orderId = flag('order');
const status = flag('status');
const dryRun = argv.includes('--dry-run');

if (!target || !title || !body) {
  console.error('Cách dùng: node send-push.mjs <email|uid> "<tiêu đề>" "<nội dung>" [--order=<mã đơn> --status=<trạng thái>] [--dry-run] --project=<id> --yes');
  process.exit(1);
}
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Emulator không có FCM; chạy với project thật.');
  process.exit(1);
}

const { admin, db } = connect(argv);

let uid = target;
if (target.includes('@')) {
  try {
    uid = (await admin.auth().getUserByEmail(target)).uid;
  } catch {
    console.error(`Không thấy tài khoản ${target}. Người đó phải đăng nhập app (Google) ít nhất một lần.`);
    process.exit(1);
  }
}

const userRef = db.doc(`users/${uid}`);
const snapshot = await userRef.get();
const tokens = Array.isArray(snapshot.data()?.fcmTokens) ? snapshot.data().fcmTokens.filter((t) => typeof t === 'string') : [];
if (tokens.length === 0) {
  console.error(`users/${uid} chưa có token FCM. Mở app trên thiết bị, cho phép thông báo, rồi thử lại.`);
  process.exit(1);
}

// "data" là chuỗi: app dùng orderId và status để mở đúng đơn và để không lưu trùng thông báo.
const data = {};
if (orderId) data.orderId = orderId;
if (status) data.status = status;

const response = await admin.messaging().sendEachForMulticast({ tokens, notification: { title, body }, data }, dryRun);

const dead = [];
response.responses.forEach((r, i) => {
  const code = r.error?.code;
  console.log(`${dryRun ? '[dry-run] ' : ''}token ${i + 1}/${tokens.length} ...${tokens[i].slice(-8)}: ${r.success ? 'OK' : code}`);
  if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') dead.push(tokens[i]);
});
if (dead.length && !dryRun) {
  await userRef.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) });
  console.log(`Đã xoá ${dead.length} token hết hạn khỏi users/${uid}.`);
}
console.log(`${response.successCount} thành công, ${response.failureCount} lỗi.`);
process.exit(response.successCount > 0 ? 0 : 2);
