import 'package:breakbite/models/models.dart';
import 'package:breakbite/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

const customer = AppUser(uid: 'a', displayName: 'A', role: UserRole.user);
const staff = AppUser(uid: 'b', displayName: 'B', role: UserRole.staff);

String? go(AppUser? u, String loc, {bool init = true}) => authRedirect(user: u, initialized: init, location: loc);

void main() {
  test('chưa biết trạng thái đăng nhập thì chưa chuyển hướng', () {
    expect(go(null, '/home', init: false), isNull);
  });

  test('chưa đăng nhập: mọi màn khách về /sign-in, màn người bán về /seller/sign-in', () {
    expect(go(null, '/home'), '/sign-in');
    expect(go(null, '/cart'), '/sign-in');
    expect(go(null, '/seller/orders'), '/seller/sign-in');
    expect(go(null, '/sign-in'), isNull);
    expect(go(null, '/seller/sign-in'), isNull);
  });

  test('đã đăng nhập: rời màn đăng nhập tới đúng app theo vai trò', () {
    expect(go(customer, '/sign-in'), '/home');
    expect(go(staff, '/sign-in'), '/seller/orders');
    expect(go(staff, '/seller/sign-in'), '/seller/orders');
  });

  test('khách không vào được vùng người bán (từ chối sai vai trò)', () {
    expect(go(customer, '/seller/orders'), '/home');
    expect(go(customer, '/seller/menu/new'), '/home');
  });

  test('người bán và khách đi lại bình thường trong vùng của mình', () {
    expect(go(customer, '/orders/A-204'), isNull);
    expect(go(staff, '/seller/orders/A-204'), isNull);
  });

  test('nhân viên mở vùng khách thì được đưa về app người bán', () {
    expect(go(staff, '/home'), '/seller/orders');
  });
}
