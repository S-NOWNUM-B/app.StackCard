import 'profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> getProfile();
}
