import Foundation
import SwiftUI

enum OfferOutcome {
    case accepted
    case walked
    case shortOfCoin
}

/// One line of the ledger's signal study, computed from the house's own settled book.
struct SignalStudyLine: Identifiable {
    var id: String { cue.rawValue }
    let cue: SignalCue
    let seen: Int
    let wentBad: Int
    let restSeen: Int
    let restBad: Int

    var rateWith: Double { seen > 0 ? Double(wentBad) / Double(seen) : 0 }
    var rateWithout: Double { restSeen > 0 ? Double(restBad) / Double(restSeen) : 0 }
    var lift: Double { rateWith - rateWithout }
    var hasEnough: Bool { seen >= 4 && restSeen >= 4 }
}

/// The saved campaign. Every field decodes with a fallback so a later version that adds
/// a field never wipes a player's house.
struct HouseSave: Codable {
    var version: Int = 1
    var houseName: String = "The House of Ardenza"
    var week: Int = 1
    var cash: Int = 2000
    var standing: Double = 50
    var staff = HouseStaff()
    var openCities: [CityID] = [.ardenza]
    var events: [MarketEvent] = []
    var queue: [LoanApplicant] = []
    var book: [LoanRecord] = []
    var alumni: [Alumnus] = []
    var weekNotes: [WeekNote] = []
    var rng = CounterRandom(seed: 20260901)
    var lifetimeInterest: Int = 0
    var lifetimeLosses: Int = 0
    var lifetimeUpkeep: Int = 0
    var walkedAway: Int = 0
    var declined: Int = 0
    var peakWorth: Int = 2000
    var hasSeenGuide: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, houseName, week, cash, standing, staff, openCities, events, queue
        case book, alumni, weekNotes, rng, lifetimeInterest, lifetimeLosses, lifetimeUpkeep
        case walkedAway, declined, peakWorth, hasSeenGuide
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? box.decode(Int.self, forKey: .version)) ?? 1
        houseName = (try? box.decode(String.self, forKey: .houseName)) ?? "The House of Ardenza"
        week = (try? box.decode(Int.self, forKey: .week)) ?? 1
        cash = (try? box.decode(Int.self, forKey: .cash)) ?? 2000
        standing = (try? box.decode(Double.self, forKey: .standing)) ?? 50
        staff = (try? box.decode(HouseStaff.self, forKey: .staff)) ?? HouseStaff()
        openCities = (try? box.decode([CityID].self, forKey: .openCities)) ?? [.ardenza]
        events = (try? box.decode([MarketEvent].self, forKey: .events)) ?? []
        queue = (try? box.decode([LoanApplicant].self, forKey: .queue)) ?? []
        book = (try? box.decode([LoanRecord].self, forKey: .book)) ?? []
        alumni = (try? box.decode([Alumnus].self, forKey: .alumni)) ?? []
        weekNotes = (try? box.decode([WeekNote].self, forKey: .weekNotes)) ?? []
        rng = (try? box.decode(CounterRandom.self, forKey: .rng)) ?? CounterRandom(seed: 20260901)
        lifetimeInterest = (try? box.decode(Int.self, forKey: .lifetimeInterest)) ?? 0
        lifetimeLosses = (try? box.decode(Int.self, forKey: .lifetimeLosses)) ?? 0
        lifetimeUpkeep = (try? box.decode(Int.self, forKey: .lifetimeUpkeep)) ?? 0
        walkedAway = (try? box.decode(Int.self, forKey: .walkedAway)) ?? 0
        declined = (try? box.decode(Int.self, forKey: .declined)) ?? 0
        peakWorth = (try? box.decode(Int.self, forKey: .peakWorth)) ?? max(2000, cash)
        hasSeenGuide = (try? box.decode(Bool.self, forKey: .hasSeenGuide)) ?? false
        if openCities.isEmpty { openCities = [.ardenza] }
    }
}

@MainActor
final class HouseLedger: ObservableObject {

    static let saveKey = "velloro.house.v1"
    static let startingCash = 2000

    @Published private(set) var save = HouseSave()

    // MARK: - Derived reads

    var houseName: String { save.houseName }
    var week: Int { save.week }
    var cash: Int { save.cash }
    var standing: Double { save.standing }
    var staff: HouseStaff { save.staff }
    var openCities: [CityID] { save.openCities }
    var events: [MarketEvent] { save.events }
    var queue: [LoanApplicant] { save.queue }
    var book: [LoanRecord] { save.book }
    var weekNotes: [WeekNote] { save.weekNotes }
    var hasSeenGuide: Bool { save.hasSeenGuide }

    var liveLoans: [LoanRecord] { save.book.filter { $0.status == .outstanding } }
    var settledLoans: [LoanRecord] { save.book.filter { $0.status.isResolved } }
    /// Coin actually out of the chest. For a bill that is the discounted price paid,
    /// not the face value, so worth never counts a gain before it is earned.
    var outstandingPrincipal: Int { liveLoans.reduce(0) { $0 + $1.cashOut } }
    var worth: Int { save.cash + outstandingPrincipal }
    var weeklyUpkeep: Int {
        save.openCities.reduce(0) { $0 + $1.weeklyUpkeep } + save.staff.weeklyWages
    }
    var activeEvents: [MarketEvent] { save.events.filter { $0.isActive(onWeek: save.week) } }
    var pendingRulings: [LoanRecord] { save.book.filter { $0.awaitingRuling } }
    var concentrationPenalty: Double { CounterEngine.concentrationPenalty(outstanding: save.book) }
    var concentrationIndex: Double { CounterEngine.concentrationIndex(outstanding: save.book) }
    var quarter: Int { (save.week - 1) / 13 + 1 }
    var year: Int { (save.week - 1) / 52 + 1 }

    var seasonLabel: String {
        switch ((save.week - 1) / 13) % 4 {
        case 0: return "Spring"
        case 1: return "Summer"
        case 2: return "Autumn"
        default: return "Winter"
        }
    }

    var isRuined: Bool {
        save.cash < 15 && liveLoans.isEmpty && save.week > 3
    }

    var unlockedInstruments: [InstrumentKind] {
        var list: [InstrumentKind] = [.loan]
        if save.peakWorth >= 2800 { list.append(.bill) }
        if save.peakWorth >= 6000 { list.append(.commenda) }
        return list
    }

    var nextInstrumentHint: String? {
        if save.peakWorth < 2800 {
            return "Bills of exchange open to a house worth 2,800 fl. Yours has reached \(Tally.florins(save.peakWorth))."
        }
        if save.peakWorth < 6000 {
            return "Commenda partnerships open to a house worth 6,000 fl. Yours has reached \(Tally.florins(save.peakWorth))."
        }
        return nil
    }

    var billCeiling: Int {
        save.staff.correspondent ? 900 : 400
    }

    // MARK: - Lifecycle

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let decoded = try? JSONDecoder().decode(HouseSave.self, from: data) else {
            startFresh()
            return
        }
        save = decoded
        if save.queue.isEmpty && pendingRulings.isEmpty { refreshQueue() }
    }

    func persist() {
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    func startFresh() {
        var fresh = HouseSave()
        fresh.cash = Self.startingCash
        fresh.peakWorth = Self.startingCash
        fresh.rng = CounterRandom(seed: UInt64.random(in: 1...UInt64(4_000_000_000)))
        fresh.hasSeenGuide = save.hasSeenGuide
        save = fresh
        refreshQueue()
        persist()
    }

    func markGuideSeen() {
        guard !save.hasSeenGuide else { return }
        save.hasSeenGuide = true
        persist()
    }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save.houseName = trimmed.isEmpty ? "The House of Ardenza" : String(trimmed.prefix(40))
        persist()
    }

    // MARK: - The counter

    private func makeContext() -> CounterContext {
        CounterContext(week: save.week, standing: save.standing, staff: save.staff,
                       openCities: save.openCities, events: save.events,
                       alumni: save.alumni, concentrationPenalty: concentrationPenalty,
                       sumScale: CounterEngine.sumScale(forWorth: max(300, worth)))
    }

    func refreshQueue() {
        var rng = save.rng
        save.queue = CounterEngine.generateQueue(context: makeContext(), rng: &rng)
        save.rng = rng
    }

    /// Cost in coin of putting the offer on the table right now.
    func outlay(for applicant: LoanApplicant, terms: OfferTerms) -> Int {
        switch terms.instrument {
        case .loan, .commenda: return applicant.amount
        case .bill: return Int((Double(applicant.amount) * (1.0 - terms.rate)).rounded())
        }
    }

    @discardableResult
    func offer(_ terms: OfferTerms, to applicant: LoanApplicant) -> OfferOutcome {
        // Idempotent: a second tap on an applicant already dealt with does nothing.
        guard save.queue.contains(where: { $0.id == applicant.id }) else { return .walked }
        let spend = outlay(for: applicant, terms: terms)
        guard save.cash >= spend else { return .shortOfCoin }

        var rng = save.rng
        let odds = CounterEngine.acceptanceOdds(applicant: applicant, terms: terms)
        let taken = rng.chance(odds)
        save.rng = rng

        save.queue.removeAll { $0.id == applicant.id }

        guard taken else {
            save.walkedAway += 1
            save.standing = LendingMath.clamp(save.standing - 0.02, 5, 100)
            persist()
            return .walked
        }

        save.cash -= spend
        let record = LoanRecord(borrower: applicant.name,
                                trade: applicant.trade,
                                city: applicant.city,
                                standing: applicant.standing,
                                instrument: terms.instrument,
                                principal: applicant.amount,
                                rate: terms.rate,
                                termWeeks: terms.termWeeks,
                                openedWeek: save.week,
                                dueWeek: save.week + terms.termWeeks,
                                pledges: terms.requiredPledges(from: applicant),
                                cuesSeen: applicant.visibleCues,
                                cuesAll: applicant.cues,
                                baseHazard: applicant.baseHazard,
                                cashOut: spend)
        save.book.append(record)
        save.peakWorth = max(save.peakWorth, worth)
        persist()
        return .accepted
    }

    func decline(_ applicant: LoanApplicant) {
        guard save.queue.contains(where: { $0.id == applicant.id }) else { return }
        save.queue.removeAll { $0.id == applicant.id }
        save.declined += 1
        save.standing = LendingMath.clamp(save.standing - 0.04, 5, 100)
        persist()
    }

    // MARK: - Turning the week

    func closeTheWeek() {
        guard pendingRulings.isEmpty else { return }

        var notes: [WeekNote] = []
        var rng = save.rng
        save.week += 1
        let concentration = CounterEngine.concentrationPenalty(outstanding: save.book)

        // Matured claims
        for index in save.book.indices
        where save.book[index].status == .outstanding && save.book[index].dueWeek <= save.week {
            let loan = save.book[index]
            let result = CounterEngine.resolve(loan: loan, staff: save.staff, events: save.events,
                                               concentration: concentration, rng: &rng)
            if let extended = result.extendUntil {
                save.book[index].dueWeek = extended
                save.book[index].wasExtended = true
                notes.append(WeekNote(kind: .late,
                                      headline: "\(loan.borrower) asks for time",
                                      detail: result.note))
                continue
            }

            save.book[index].status = result.status
            save.book[index].resolvedWeek = save.week
            save.standing = LendingMath.clamp(save.standing + result.standingDelta, 5, 100)

            if result.status == .defaulted && loan.instrument == .loan {
                save.book[index].awaitingRuling = true
                notes.append(WeekNote(kind: .failed,
                                      headline: "\(loan.borrower) cannot pay",
                                      detail: result.note))
            } else {
                save.book[index].cashIn = result.cashIn
                save.cash += result.cashIn
                recordSettlement(save.book[index])
                let kind: WeekNoteKind
                switch result.status {
                case .repaidOnTime: kind = .repaid
                case .repaidLate: kind = .late
                case .repaidPartly: kind = .partial
                default: kind = .failed
                }
                notes.append(WeekNote(kind: kind,
                                      headline: "\(loan.borrower) — \(result.status.label.lowercased())",
                                      detail: result.note,
                                      amount: result.cashIn - loan.cashOut))
                registerAlumnus(save.book[index])
            }
        }

        // The wages and the rent
        let cost = weeklyUpkeep
        let paid = min(cost, max(0, save.cash))
        save.cash -= cost
        save.lifetimeUpkeep += paid
        if save.cash < 0 {
            save.cash = 0
            save.standing = LendingMath.clamp(save.standing - 2.0, 5, 100)
            notes.append(WeekNote(kind: .upkeep,
                                  headline: "The house could not meet its wages",
                                  detail: "Only \(paid) of \(cost) florins could be found. Word gets about, and the standing of the house suffers.",
                                  amount: -paid))
        } else {
            notes.append(WeekNote(kind: .upkeep,
                                  headline: "Wages and rent paid",
                                  detail: "The counter, its clerks and the branch houses.",
                                  amount: -cost))
        }

        // The season's news
        save.events.removeAll { $0.endWeek < save.week - 1 }
        let stillRunning = save.events.filter { $0.isActive(onWeek: save.week) }.count
        if stillRunning < 2 && rng.chance(0.13) {
            let event = CounterEngine.eventTable(week: save.week, rng: &rng)
            save.events.append(event)
            notes.append(WeekNote(kind: .event, headline: event.title, detail: event.detail))
        }

        save.rng = rng
        save.weekNotes = notes
        save.peakWorth = max(save.peakWorth, worth)
        if pendingRulings.isEmpty { refreshQueue() }
        persist()
    }

    func rule(on loanID: UUID, choice: RecoveryChoice) {
        guard let index = save.book.firstIndex(where: { $0.id == loanID }), save.book[index].awaitingRuling else { return }
        let result = CounterEngine.recovery(for: save.book[index], choice: choice, staff: save.staff)
        save.book[index].recoveryChoice = choice
        save.book[index].cashIn = result.cash
        save.book[index].awaitingRuling = false
        save.cash += result.cash
        save.standing = LendingMath.clamp(save.standing + result.standing, 5, 100)
        recordSettlement(save.book[index])
        registerAlumnus(save.book[index])
        save.peakWorth = max(save.peakWorth, worth)

        save.weekNotes.append(WeekNote(
            kind: .ruling,
            headline: "\(save.book[index].borrower) — \(choice.label.lowercased())",
            detail: choice == .seized
                ? "The pledges were sold. The city notes that this house presses its claims."
                : "Terms were composed. Less coin returns, but the house is spoken of kindly.",
            amount: save.book[index].profit))

        if pendingRulings.isEmpty { refreshQueue() }
        persist()
    }

    private func recordSettlement(_ loan: LoanRecord) {
        let delta = loan.cashIn - loan.cashOut
        if delta >= 0 { save.lifetimeInterest += delta } else { save.lifetimeLosses += -delta }
    }

    private func registerAlumnus(_ loan: LoanRecord) {
        let honoured = loan.status == .repaidOnTime || loan.status == .repaidLate
        save.alumni.append(Alumnus(name: loan.borrower, trade: loan.trade,
                                   city: loan.city, honoured: honoured))
        if save.alumni.count > 70 { save.alumni.removeFirst(save.alumni.count - 70) }
    }

    // MARK: - Investing in the house

    static let clerkCosts = [800, 2400, 6000]
    static let assayerCosts = [700, 2400]
    static let notaryCosts = [1200, 3800]
    static let correspondentCost = 2200

    func hireClerk() {
        let tier = save.staff.clerkTier
        guard tier < 3, save.cash >= Self.clerkCosts[tier] else { return }
        save.cash -= Self.clerkCosts[tier]
        save.staff.clerkTier += 1
        // A new pair of eyes reads the applicants already at the counter.
        for index in save.queue.indices {
            save.queue[index].visibleCount = min(save.queue[index].cues.count, save.staff.revealCapacity)
        }
        persist()
    }

    func hireAssayer() {
        let tier = save.staff.assayerTier
        guard tier < 2, save.cash >= Self.assayerCosts[tier] else { return }
        save.cash -= Self.assayerCosts[tier]
        save.staff.assayerTier += 1
        persist()
    }

    func hireNotary() {
        let tier = save.staff.notaryTier
        guard tier < 2, save.cash >= Self.notaryCosts[tier] else { return }
        save.cash -= Self.notaryCosts[tier]
        save.staff.notaryTier += 1
        persist()
    }

    func engageCorrespondent() {
        guard !save.staff.correspondent, save.cash >= Self.correspondentCost else { return }
        save.cash -= Self.correspondentCost
        save.staff.correspondent = true
        persist()
    }

    func openCounter(in city: CityID) {
        guard !save.openCities.contains(city), save.cash >= city.openingCost else { return }
        save.cash -= city.openingCost
        save.openCities.append(city)
        refreshQueue()
        persist()
    }

    // MARK: - The signal study

    /// What the house's own settled book says about each cue. This is the only place the
    /// player can learn the weights, and it is built from their records alone.
    func signalStudy() -> [SignalStudyLine] {
        let settled = save.book.filter { $0.status.isResolved }
        guard !settled.isEmpty else { return [] }
        func wentBad(_ loan: LoanRecord) -> Bool {
            loan.status == .defaulted || loan.status == .repaidPartly
        }
        var lines: [SignalStudyLine] = []
        for cue in SignalCue.allCases {
            var seen = 0, bad = 0, restSeen = 0, restBad = 0
            for loan in settled {
                if loan.cuesAll.contains(cue) {
                    seen += 1
                    if wentBad(loan) { bad += 1 }
                } else {
                    restSeen += 1
                    if wentBad(loan) { restBad += 1 }
                }
            }
            guard seen > 0 else { continue }
            lines.append(SignalStudyLine(cue: cue, seen: seen, wentBad: bad,
                                         restSeen: restSeen, restBad: restBad))
        }
        return lines.sorted { left, right in
            if left.hasEnough != right.hasEnough { return left.hasEnough }
            return abs(left.lift) > abs(right.lift)
        }
    }

    var overallFailureRate: Double {
        let settled = save.book.filter { $0.status.isResolved }
        guard !settled.isEmpty else { return 0 }
        let bad = settled.filter { $0.status == .defaulted || $0.status == .repaidPartly }.count
        return Double(bad) / Double(settled.count)
    }

    func exposure(by sector: HouseSector) -> Int {
        liveLoans.filter { $0.sector == sector }.reduce(0) { $0 + $1.principal }
    }
}
