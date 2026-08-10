// ─────────────────────────────────────────
// Model: UserModel
// Description: Dart model for the Firestore users collection document.
// Contains: fromMap, toMap, role, location, allergies
// ─────────────────────────────────────────

class UserModel {
  String? name;
  String? email;
  String? phone;
  String? uID;
  String? image;
  String? cover;
  String? bio;
  bool isChef;
  bool isEmailVerified;
  bool isOrganization;
  String? organizationName;
  bool hideAddressTitle;

  UserModel({
    this.name,
    this.email,
    this.phone,
    this.uID,
    this.image,
    this.cover,
    this.bio,
    this.isEmailVerified = false,
    this.isChef = false,
    this.isOrganization = false,
    this.organizationName,
    this.hideAddressTitle = false,
  });

  // Convert JSON to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? "No Name",
      email: json['email'] ?? "No Email",
      phone: json['phone'] ?? "No Phone",
      uID: json['uID'] ?? "",
      image: json['image'] ?? "default_image.png",
      cover: json['cover'] ?? "",
      bio: json['bio'] ?? "No bio available",
      isEmailVerified: json['isEmailVerified'] ?? false,
      isChef: json['isChef'] ?? false,
      isOrganization: json['isOrganization'] ?? false,
      organizationName: json['organizationName'] as String?,
      hideAddressTitle: json['hideAddressTitle'] ?? false,
    );
  }

  // Convert UserModel to Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'uID': uID,
      'image': image,
      'cover': cover,
      'bio': bio,
      'isEmailVerified': isEmailVerified,
      'isChef': isChef,
      'isOrganization': isOrganization,
      'organizationName': organizationName,
      'hideAddressTitle': hideAddressTitle,
    };
  }

  /// Display name: organization name if org, personal name otherwise
  String get displayName =>
      (isOrganization && organizationName != null && organizationName!.isNotEmpty)
          ? organizationName!
          : (name ?? 'User');
}