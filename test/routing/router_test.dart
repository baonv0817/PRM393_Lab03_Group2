import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/router.dart';
import 'package:flutter_test/flutter_test.dart';

const customer = AppUser(uid: 'a', displayName: 'A', role: UserRole.user);
const staff = AppUser(uid: 'b', displayName: 'B', role: UserRole.staff);

String? go(AppUser? u, String loc, {bool init = true, bool onboarded = true}) =>
    authRedirect(user: u, initialized: init, location: loc, onboardingDone: onboarded);

void main() {
  test('does not redirect while sign-in state is unknown', () {
    expect(go(null, '/home', init: false), isNull);
  });

  test('signed out: customer screens go to /sign-in, seller screens go to /seller/sign-in', () {
    expect(go(null, '/home'), '/sign-in');
    expect(go(null, '/cart'), '/sign-in');
    expect(go(null, '/seller/orders'), '/seller/sign-in');
    expect(go(null, '/sign-in'), isNull);
    expect(go(null, '/seller/sign-in'), isNull);
  });

  test('signed in: leaves the sign-in screen for the app matching the role', () {
    expect(go(customer, '/sign-in'), '/home');
    expect(go(staff, '/sign-in'), '/seller/orders');
    expect(go(staff, '/seller/sign-in'), '/seller/orders');
  });

  test('signed out and Onboarding not seen: customer screens go to /onboarding (S01)', () {
    expect(go(null, '/home', onboarded: false), '/onboarding');
    expect(go(null, '/sign-in', onboarded: false), '/onboarding');
    expect(go(null, '/onboarding', onboarded: false), isNull);
  });

  test('after Onboarding goes to /sign-in and never returns to Onboarding', () {
    expect(go(null, '/onboarding'), '/sign-in');
    expect(go(null, '/home'), '/sign-in');
  });

  test('seller app has no Onboarding', () {
    expect(go(null, '/seller/orders', onboarded: false), '/seller/sign-in');
    expect(go(null, '/seller/sign-in', onboarded: false), isNull);
  });

  test('signed-in users never see Onboarding', () {
    expect(go(customer, '/onboarding', onboarded: false), '/home');
    expect(go(staff, '/onboarding', onboarded: false), '/seller/orders');
  });

  test('customers cannot enter the seller area (wrong role is rejected)', () {
    expect(go(customer, '/seller/orders'), '/home');
    expect(go(customer, '/seller/menu/new'), '/home');
  });

  test('sellers and customers navigate freely within their own area', () {
    expect(go(customer, '/orders/A-204'), isNull);
    expect(go(staff, '/seller/orders/A-204'), isNull);
  });

  test('staff opening a customer route are sent to the seller app', () {
    expect(go(staff, '/home'), '/seller/orders');
  });
}
