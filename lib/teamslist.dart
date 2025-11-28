class TeamListPage extends StatelessWidget {
  final String sportName;
  final String sportId;

  const TeamListPage({
    super.key,
    required this.sportName,
    required this.sportId,
  });

  Future<List<TeamSummary>> _fetch() => teamsRepo.fetchTeamsBySport(sportId);

  @override
  Widget build(BuildContext context) {
    navController.setIndex(-1);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        title: Text(
          "$sportName Teams",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddTeamPage(sportName: sportName, sportId: sportId),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: FutureBuilder<List<TeamSummary>>(
          future: _fetch(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  "Failed to load teams\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }
            final teams = snap.data ?? <TeamSummary>[];
            if (teams.isEmpty) {
              return const Center(
                child: Text(
                  "No teams found.",
                  style: TextStyle(color: Colors.black87),
                ),
              );
            }

            return ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () async {
                      // 🔹 Send teamId to backend, details page will fetch and render
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamDetailsPage(
                            teamId: team.id,
                            teamName: team.name,
                            sportName: sportName,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.group_rounded,
                                color: Colors.green,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const PersistentNavBar(),
    );
  }
}