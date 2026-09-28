import Foundation

// Converts raw ESPN payloads into FootMob domain models.

extension ESPNTeam {
    func toTeam(league: League) -> Team? {
        guard let id = id?.value else { return nil }
        let logo = self.logo ?? logos?.values.first?.href
        return Team(
            espnID: id,
            league: league,
            abbreviation: abbreviation ?? String((displayName ?? "?").prefix(3)).uppercased(),
            displayName: displayName ?? [location, name].compactMap { $0 }.joined(separator: " "),
            shortDisplayName: shortDisplayName ?? name ?? displayName,
            location: location ?? "",
            nickname: nickname ?? name ?? "",
            colorHex: color,
            alternateColorHex: alternateColor,
            logoURL: InputValidation.imageURL(logo)
        )
    }
}

extension ESPNStatus {
    func toStatus() -> GameStatus {
        let name = type?.name ?? ""
        let state: GameStatus.State
        if name.contains("POSTPONED") || name.contains("SUSPENDED") {
            state = .postponed
        } else if name.contains("CANCELED") || name.contains("CANCELLED") {
            state = .canceled
        } else {
            switch type?.state {
            case "in": state = .live
            case "post": state = .final
            default: state = .scheduled
            }
        }
        let period = self.period ?? 0
        return GameStatus(
            state: state,
            period: period,
            displayClock: displayClock ?? "0:00",
            detail: type?.detail ?? type?.description ?? "",
            shortDetail: type?.shortDetail ?? type?.detail ?? "",
            isHalftime: name == "STATUS_HALFTIME",
            isOvertime: period > 4
        )
    }
}

extension ESPNCompetitor {
    func toCompetitor(league: League) -> Competitor? {
        guard let team = team?.toTeam(league: league) else { return nil }
        let allRecords = (records?.values ?? []) + (record?.values ?? [])
        let overall = allRecords.first { $0.type == "total" || $0.name == "overall" || $0.name == "All Splits" }
            ?? allRecords.first
        let rank = curatedRank?.current.flatMap { (1...25).contains($0) ? $0 : nil }
        return Competitor(
            team: team,
            score: score?.value,
            record: overall?.summary ?? overall?.displayValue,
            rank: rank,
            linescores: linescores?.values.compactMap { line in line.value.map { Int($0) } } ?? [],
            isWinner: winner
        )
    }
}

extension ESPNSituation {
    func toSituation(home: Team, away: Team) -> Situation {
        Situation(
            down: down,
            distance: distance,
            downDistanceText: downDistanceText,
            shortDownDistanceText: shortDownDistanceText,
            possessionText: possessionText,
            possessionTeamID: possession?.value,
            isRedZone: isRedZone ?? false,
            homeTimeouts: homeTimeouts,
            awayTimeouts: awayTimeouts,
            lastPlay: lastPlay?.text,
            fieldPosition: Self.fieldPosition(possessionText: possessionText, home: home, away: away)
        )
    }

    /// Converts "DAL 25" into yards from the away goal line. Midfield is reported as "50".
    static func fieldPosition(possessionText: String?, home: Team, away: Team) -> Double? {
        guard let text = possessionText?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        let parts = text.split(separator: " ")
        if parts.count == 1, let yard = Double(parts[0]) { return yard }
        guard parts.count == 2, let yard = Double(parts[1]) else { return nil }
        let side = String(parts[0]).uppercased()
        if side == away.abbreviation.uppercased() { return yard }
        if side == home.abbreviation.uppercased() { return 100 - yard }
        return nil
    }
}

extension ESPNCompetition {
    func toGame(eventID: String, league: League, eventDate: String?, name: String?, shortName: String?,
                week: Int?, season: ESPNSeason?, fallbackStatus: ESPNStatus?) -> Game? {
        let competitors = self.competitors?.values ?? []
        guard
            let homeRaw = competitors.first(where: { $0.homeAway == "home" }) ?? competitors.last,
            let awayRaw = competitors.first(where: { $0.homeAway == "away" }) ?? competitors.first,
            let home = homeRaw.toCompetitor(league: league),
            let away = awayRaw.toCompetitor(league: league),
            let date = ESPNDate.parse(date ?? eventDate)
        else { return nil }

        let status = (self.status ?? fallbackStatus)?.toStatus() ?? GameStatus(state: .scheduled)
        var broadcastNames: [String] = []
        for name in broadcasts?.values.flatMap({ $0.names ?? [$0.media?.shortName].compactMap { $0 } }) ?? []
        where !broadcastNames.contains(name) {
            broadcastNames.append(name)
        }
        let odds = self.odds?.values.first
        let city = [venue?.address?.city, venue?.address?.state].compactMap { $0 }.joined(separator: ", ")

        return Game(
            id: eventID,
            league: league,
            date: date,
            name: name ?? "\(away.team.displayName) at \(home.team.displayName)",
            shortName: shortName ?? "\(away.team.abbreviation) @ \(home.team.abbreviation)",
            week: week,
            seasonType: season?.type,
            seasonYear: season?.year,
            away: away,
            home: home,
            status: status,
            situation: status.isLive ? situation?.toSituation(home: home.team, away: away.team) : nil,
            venue: venue?.fullName,
            city: city.isEmpty ? nil : city,
            broadcast: broadcastNames.isEmpty ? nil : broadcastNames.joined(separator: ", "),
            odds: odds?.details,
            overUnder: odds?.overUnder,
            headline: notes?.values.first?.headline
        )
    }
}

extension ESPNEvent {
    func toGame(league: League) -> Game? {
        competitions?.values.first?.toGame(
            eventID: id.value, league: league, eventDate: date, name: name, shortName: shortName,
            week: week?.number, season: season, fallbackStatus: status
        )
    }
}

extension ESPNScoreboard {
    func toScoreboard(league: League) -> Scoreboard {
        let games = (events?.values ?? []).compactMap { $0.toGame(league: league) }.sorted { $0.date < $1.date }
        let calendar = (leagues?.values.first?.calendar ?? []).flatMap { section -> [WeekSelection] in
            guard let type = section.value.flatMap({ Int($0.value) }) else { return [] }
            return (section.entries?.values ?? []).compactMap { entry in
                guard let week = entry.value.flatMap({ Int($0.value) }) else { return nil }
                return WeekSelection(
                    seasonType: type,
                    week: week,
                    label: entry.label ?? "Week \(week)",
                    startDate: ESPNDate.parse(entry.startDate),
                    endDate: ESPNDate.parse(entry.endDate)
                )
            }
        }
        var current: WeekSelection?
        if let type = season?.type, let number = week?.number {
            current = calendar.first { $0.seasonType == type && $0.week == number }
                ?? WeekSelection(seasonType: type, week: number, label: "Week \(number)")
        }
        return Scoreboard(league: league, games: games, week: current, calendar: calendar)
    }
}

extension ESPNSummary {
    func toDetail(league: League, gameID: String) -> GameDetail? {
        guard let game = header?.competitions?.values.first?.toGame(
            eventID: header?.id?.value ?? gameID, league: league, eventDate: nil, name: nil, shortName: nil,
            week: header?.week, season: header?.season, fallbackStatus: nil
        ) else { return nil }

        var detail = GameDetail(game: game)
        if detail.game.venue == nil { detail.game.venue = gameInfo?.venue?.fullName }

        // Team stats: pair up away/home rows by stat name.
        let boxTeams = boxscore?.teams?.values ?? []
        func boxTeam(_ side: Side) -> ESPNSummary.BoxTeam? {
            let espnID = game.competitor(for: side).team.espnID
            return boxTeams.first { $0.homeAway == side.rawValue } ?? boxTeams.first { $0.team?.id?.value == espnID }
        }
        if let awayBox = boxTeam(.away), let homeBox = boxTeam(.home) {
            let homeStats = Dictionary((homeBox.statistics?.values ?? []).compactMap { stat in
                stat.name.map { ($0, stat) }
            }, uniquingKeysWith: { first, _ in first })
            detail.teamStats = (awayBox.statistics?.values ?? []).compactMap { stat in
                guard let key = stat.name, let home = homeStats[key] else { return nil }
                return TeamStatLine(
                    key: key,
                    label: stat.label ?? key,
                    away: stat.displayValue ?? "-",
                    home: home.displayValue ?? "-"
                )
            }
        }

        detail.scoringPlays = (scoringPlays?.values ?? []).enumerated().map { index, play in
            ScoringPlay(
                id: play.id?.value ?? "score-\(index)",
                teamKey: play.team?.id.map { Team.key(league: league, espnID: $0.value) },
                teamAbbreviation: play.team?.abbreviation,
                typeAbbreviation: play.type?.abbreviation ?? "",
                typeText: play.type?.text ?? "Score",
                text: play.text ?? "",
                period: play.period?.number ?? 0,
                clock: play.clock?.displayValue ?? "",
                awayScore: play.awayScore ?? 0,
                homeScore: play.homeScore ?? 0
            )
        }

        func mapDrive(_ drive: ESPNDrive, index: Int, isCurrent: Bool) -> Drive {
            Drive(
                id: drive.id?.value ?? "drive-\(index)",
                teamKey: drive.team?.id.map { Team.key(league: league, espnID: $0.value) },
                teamAbbreviation: drive.team?.abbreviation,
                summary: drive.description ?? "",
                result: drive.displayResult ?? drive.result ?? (isCurrent ? "In progress" : ""),
                isScore: drive.isScore ?? false,
                isCurrent: isCurrent,
                plays: (drive.plays?.values ?? []).enumerated().map { playIndex, play in
                    Play(
                        id: play.id?.value ?? "\(index)-\(playIndex)",
                        text: play.text ?? "",
                        downDistance: play.start?.downDistanceText,
                        period: play.period?.number ?? 0,
                        clock: play.clock?.displayValue ?? "",
                        isScoring: play.scoringPlay ?? false
                    )
                }
            )
        }
        var drives = (self.drives?.previous?.values ?? []).enumerated().map { mapDrive($1, index: $0, isCurrent: false) }
        if let current = self.drives?.current, game.status.isLive {
            let mapped = mapDrive(current, index: drives.count, isCurrent: true)
            drives.removeAll { $0.id == mapped.id }
            drives.append(mapped)
        }
        detail.drives = drives.reversed()

        detail.winProbability = (winprobability?.values ?? []).enumerated().compactMap { index, point in
            point.homeWinPercentage.map { WinProbabilityPoint(index: index, homeWinProbability: $0) }
        }

        // Leaders: merge each team's categories into away/home pairs.
        var categories: [String: LeaderCategory] = [:]
        var order: [String] = []
        for teamLeaders in leaders?.values ?? [] {
            let teamID = teamLeaders.team?.id?.value
            let side: Side = teamID == game.home.team.espnID ? .home : .away
            for category in teamLeaders.leaders?.values ?? [] {
                guard let key = category.name, let top = category.leaders?.values.first else { continue }
                let leader = PlayerLeader(
                    name: top.athlete?.displayName ?? "",
                    shortName: top.athlete?.shortName ?? top.athlete?.displayName ?? "",
                    position: top.athlete?.position?.abbreviation,
                    headshotURL: InputValidation.imageURL(top.athlete?.headshot?.href),
                    statLine: top.displayValue ?? ""
                )
                if categories[key] == nil {
                    order.append(key)
                    categories[key] = LeaderCategory(key: key, title: category.displayName ?? key, away: nil, home: nil)
                }
                if side == .home { categories[key]?.home = leader } else { categories[key]?.away = leader }
            }
        }
        detail.leaders = order.compactMap { categories[$0] }

        detail.articles = (news?.articles?.values ?? []).compactMap { $0.toArticle(league: league) }
        return detail
    }
}

extension ESPNArticle {
    func toArticle(league: League) -> Article? {
        guard let headline, !headline.isEmpty else { return nil }
        let teamIDs = (categories?.values ?? []).compactMap { category -> String? in
            guard category.type == "team" else { return nil }
            return category.teamId?.value ?? category.team?.id?.value
        }
        let url = InputValidation.webURL(links?.web?.href)
        return Article(
            id: id?.value ?? url?.absoluteString ?? headline,
            league: league,
            headline: headline,
            summary: description ?? "",
            published: ESPNDate.parse(published),
            imageURL: InputValidation.imageURL(images?.values.first?.url),
            url: url,
            byline: byline,
            teamIDs: Array(Set(teamIDs)).sorted()
        )
    }
}

extension ESPNStandingsNode {
    /// Walks the conference/division tree and returns every node that carries standings.
    func toGroups(league: League) -> [StandingsGroup] {
        var groups: [StandingsGroup] = []
        if let entries = standings?.entries?.values, !entries.isEmpty {
            let mapped = entries.compactMap { $0.toEntry(league: league) }
            let sorted = mapped.sorted { lhs, rhs in
                switch (lhs.playoffSeed, rhs.playoffSeed) {
                case let (l?, r?) where l != r: return l < r
                default:
                    if lhs.winPercent != rhs.winPercent { return lhs.winPercent > rhs.winPercent }
                    return lhs.wins > rhs.wins
                }
            }
            let name = self.name ?? abbreviation ?? "Standings"
            groups.append(StandingsGroup(
                id: id?.value ?? name,
                name: name,
                shortName: abbreviation ?? shortName ?? name,
                entries: sorted
            ))
        }
        for child in children?.values ?? [] {
            groups.append(contentsOf: child.toGroups(league: league))
        }
        return groups
    }
}

extension ESPNStandingsNode.Entry {
    func toEntry(league: League) -> StandingsEntry? {
        guard let team = team?.toTeam(league: league) else { return nil }
        let stats = self.stats?.values ?? []
        func stat(_ names: String...) -> ESPNStandingsNode.Stat? {
            stats.first { stat in names.contains { $0 == stat.name || $0 == stat.type } }
        }
        func int(_ names: String...) -> Int? {
            stats.first { stat in names.contains { $0 == stat.name || $0 == stat.type } }?.value.map { Int($0) }
        }

        var wins = int("wins") ?? 0
        var losses = int("losses") ?? 0
        let ties = int("ties") ?? 0
        // College feeds sometimes only provide an "overall" summary like "7-2".
        if wins == 0, losses == 0, let overall = stat("overall", "total")?.displayValue ?? stat("overall", "total")?.summary {
            let parts = overall.split(separator: "-").compactMap { Int($0) }
            if parts.count >= 2 { wins = parts[0]; losses = parts[1] }
        }
        let games = wins + losses + ties
        let computedPct = games > 0 ? (Double(wins) + Double(ties) / 2) / Double(games) : 0
        let clincher = stat("clincher")?.displayValue

        return StandingsEntry(
            team: team,
            wins: wins,
            losses: losses,
            ties: ties,
            winPercent: stat("winPercent")?.value ?? computedPct,
            pointsFor: int("pointsFor"),
            pointsAgainst: int("pointsAgainst"),
            streak: stat("streak")?.displayValue,
            playoffSeed: int("playoffSeed").flatMap { $0 > 0 ? $0 : nil },
            conferenceRecord: stat("vsconf", "vs. Conf.", "vsConf")?.displayValue ?? stat("vsconf")?.summary,
            clincher: (clincher?.isEmpty ?? true) || clincher == "-" ? nil : clincher
        )
    }
}
