class UserModel {
  String? name;
  String? email;
  String? phone;
  String? uID;
  String? image;
  String? cover;
  String? bio;
  bool isEmailVerified;

  UserModel({
    this.name,
    this.email,
    this.phone,
    this.uID,
    this.image,
    this.cover,
    this.bio,
    this.isEmailVerified = false,
  });

  // Convert JSON to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? "No Name", // Provide a default value
      email: json['email'] ?? "No Email",
      phone: json['phone'] ?? "No Phone",
      uID: json['uID'] ?? "",
      image: json['image'] ?? "default_image.png",
      cover: json['cover'] ?? "",
      bio: json['bio'] ?? "No bio available",
      isEmailVerified: json['isEmailVerified'] ?? false,
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
    };
  }
}