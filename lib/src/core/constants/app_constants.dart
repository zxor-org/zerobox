class TeamMember {
  const TeamMember({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.githubUrl,
  });

  final String name;
  final String role;
  final String avatarAsset;
  final String githubUrl;
}

abstract final class AppConstants {
  static const String githubRepoUrl = 'https://github.com/zxor-org/zerobox';

  static const List<TeamMember> teamMembers = [
    TeamMember(
      name: 'OrPudding',
      role: '主开发 / 设计',
      avatarAsset: 'assets/images/team/orpudding.jpg',
      githubUrl: 'https://github.com/orpudding',
    ),
    TeamMember(
      name: 'zxxhcj',
      role: 'ZeppOS 实现',
      avatarAsset: 'assets/images/team/zxxhcj.jpg',
      githubUrl: 'https://github.com/zxxhcj',
    ),
  ];
}
