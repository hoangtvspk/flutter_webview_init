class UserInfo {
  String? fullName;
  String? email;
  String? socialId;
  String? avatar;
  String? id;
  String? roleId;

  UserInfo(
      {this.fullName,
      this.email,
      this.socialId,
      this.avatar,
      this.id,
      this.roleId});

  UserInfo.fromJson(Map<String, dynamic> json) {
    fullName = json["fullName"];
    email = json["email"];
    socialId = json["socialId"];
    avatar = json["avatar"];
    id = json["id"];
    roleId = json["roleId"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["fullName"] = fullName;
    data["email"] = email;
    data["socialId"] = socialId;
    data["avatar"] = avatar;
    data["id"] = id;
    data["roleId"] = roleId;
    return data;
  }
}
