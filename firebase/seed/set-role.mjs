// Gán vai trò cho một tài khoản đã đăng nhập app ít nhất một lần (để có uid).
//
//   node set-role.mjs <email> <user|staff|admin> [kioskId] --project=<id> --yes
//
// Ví dụ: node set-role.mjs hanh@gmail.com staff q9-t2 --project=breakbite-1315b --yes
// Staff bắt buộc có kioskId; user và admin thì bỏ kioskId. Cần GOOGLE_APPLICATION_CREDENTIALS
// (khoá service account ngoài repo); chỉ dùng cho project thật vì Auth Emulator không chạy ở đây.
import { connect } from './admin.mjs';

const argv = process.argv.slice(2);
const [email, role, kioskId] = argv.filter((a) => !a.startsWith('--'));

if (!email || !['user', 'staff', 'admin'].includes(role)) {
  console.error('Cách dùng: node set-role.mjs <email> <user|staff|admin> [kioskId] --project=<id> --yes');
  process.exit(1);
}
if (role === 'staff' && !kioskId) {
  console.error('Staff phải có kioskId (ví dụ q9-t2).');
  process.exit(1);
}

const { admin, db } = connect(argv);

const kiosk = role === 'staff' ? await db.doc(`kiosks/${kioskId}`).get() : null;
if (kiosk && !kiosk.exists) {
  console.error(`Không có kiosk "${kioskId}". Đã chạy seed.mjs chưa?`);
  process.exit(1);
}

let user;
try {
  user = await admin.auth().getUserByEmail(email);
} catch {
  console.error(`Không thấy tài khoản ${email}. Người đó phải đăng nhập app (Google) ít nhất một lần.`);
  process.exit(1);
}

const { FieldValue } = admin.firestore;
await db.doc(`users/${user.uid}`).set(
  {
    role,
    kioskId: role === 'staff' ? kioskId : FieldValue.delete(),
    displayName: user.displayName ?? email,
    email,
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);
console.log(`Đã đặt ${email} (${user.uid}) thành ${role}${role === 'staff' ? ` của kiosk ${kioskId}` : ''}.`);
