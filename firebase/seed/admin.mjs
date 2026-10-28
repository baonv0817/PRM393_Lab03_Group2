// Khởi tạo Firebase Admin dùng chung cho các script. Admin SDK bỏ qua Security Rules,
// nên chỉ chạy script khi biết mình ghi vào đâu:
//  - Emulator: có biến FIRESTORE_EMULATOR_HOST (do `firebase emulators:exec` đặt), không cần khoá.
//  - Project thật: truyền --project=<id> và đặt GOOGLE_APPLICATION_CREDENTIALS trỏ tới khoá service
//    account tải từ console (Project settings, Service accounts). Khoá nằm NGOÀI repo, không commit.
import admin from 'firebase-admin';

export function connect(argv) {
  const projectArg = argv.find((a) => a.startsWith('--project='))?.split('=')[1];
  const emulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

  if (emulator) {
    const projectId = process.env.GCLOUD_PROJECT || projectArg || 'demo-breakbite';
    admin.initializeApp({ projectId });
    return { admin, db: admin.firestore(), projectId, emulator: true };
  }

  if (!projectArg) {
    throw new Error('Thiếu --project=<id>. Ghi vào project thật cần nêu rõ id, ví dụ --project=breakbite-1315b.');
  }
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Thiếu GOOGLE_APPLICATION_CREDENTIALS: đặt đường dẫn tới file khoá service account (ngoài repo).');
  }
  if (!argv.includes('--yes')) {
    throw new Error(`Sắp ghi vào project THẬT "${projectArg}". Thêm --yes để xác nhận.`);
  }
  admin.initializeApp({ projectId: projectArg, credential: admin.credential.applicationDefault() });
  return { admin, db: admin.firestore(), projectId: projectArg, emulator: false };
}
