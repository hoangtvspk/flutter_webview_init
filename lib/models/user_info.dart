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
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["fullName"] = fullName;
    _data["email"] = email;
    _data["socialId"] = socialId;
    _data["avatar"] = avatar;
    _data["id"] = id;
    _data["roleId"] = roleId;
    return _data;
  }
}
