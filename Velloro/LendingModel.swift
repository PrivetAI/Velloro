import Foundation

// MARK: - Deterministic random source
//
// A small SplitMix64 generator. It is Codable so a campaign resumes with the exact
// stream it was saved with, and so the headless balance harness can replay a seed.

struct CounterRandom: Codable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x2545_F491_4F6C_DD1D
    }

    // Persisted as a SIGNED bit pattern on purpose. Half of all SplitMix64 states exceed
    // Int64.max, and older Foundation refuses to decode a JSON integer that large — the
    // stream would quietly reset to the seed on every cold launch.
    enum CodingKeys: String, CodingKey { case signedState }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        let signed = (try? box.decode(Int64.self, forKey: .signedState)) ?? 0
        state = UInt64(bitPattern: signed)
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(Int64(bitPattern: state), forKey: .signedState)
    }

    mutating func nextBits() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        Double(nextBits() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func span(_ low: Double, _ high: Double) -> Double {
        low + (high - low) * unit()
    }

    /// Inclusive on both ends.
    mutating func whole(_ low: Int, _ high: Int) -> Int {
        guard high > low else { return low }
        return low + Int(unit() * Double(high - low + 1))
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    mutating func normal() -> Double {
        let u1 = max(1e-12, unit())
        let u2 = unit()
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * Double.pi * u2)
    }

    mutating func choose<T>(_ items: [T]) -> T {
        items[whole(0, items.count - 1)]
    }

    /// Weighted pick; weights must be non-negative and not all zero.
    mutating func chooseWeighted<T>(_ items: [T], _ weights: [Double]) -> T {
        let total = weights.reduce(0, +)
        guard total > 0 else { return choose(items) }
        var roll = unit() * total
        for index in 0..<items.count {
            roll -= weights[index]
            if roll <= 0 { return items[index] }
        }
        return items[items.count - 1]
    }
}

// MARK: - Sectors and trades

enum HouseSector: String, Codable, CaseIterable {
    case cloth, sea, land, stone, craft

    var label: String {
        switch self {
        case .cloth: return "Cloth"
        case .sea: return "Sea"
        case .land: return "Land"
        case .stone: return "Stone"
        case .craft: return "Craft"
        }
    }
}

enum TradeID: String, Codable, CaseIterable {
    case woolWeaver, silkDyer, fuller
    case spiceFactor, shipwright, saltTrader
    case vintner, grainFactor, drover
    case stonemason, tiler
    case glassblower, armourer, apothecary

    var label: String {
        switch self {
        case .woolWeaver: return "Wool Weaver"
        case .silkDyer: return "Silk Dyer"
        case .fuller: return "Fuller"
        case .spiceFactor: return "Spice Factor"
        case .shipwright: return "Shipwright"
        case .saltTrader: return "Salt Trader"
        case .vintner: return "Vintner"
        case .grainFactor: return "Grain Factor"
        case .drover: return "Drover"
        case .stonemason: return "Stonemason"
        case .tiler: return "Tiler"
        case .glassblower: return "Glassblower"
        case .armourer: return "Armourer"
        case .apothecary: return "Apothecary"
        }
    }

    var sector: HouseSector {
        switch self {
        case .woolWeaver, .silkDyer, .fuller: return .cloth
        case .spiceFactor, .shipwright, .saltTrader: return .sea
        case .vintner, .grainFactor, .drover: return .land
        case .stonemason, .tiler: return .stone
        case .glassblower, .armourer, .apothecary: return .craft
        }
    }

    /// Hidden contribution to the default log-odds. Never shown as a number.
    var hazard: Double {
        switch self {
        case .woolWeaver: return 0.02
        case .silkDyer: return 0.14
        case .fuller: return 0.06
        case .spiceFactor: return 0.36
        case .shipwright: return 0.24
        case .saltTrader: return 0.28
        case .vintner: return 0.16
        case .grainFactor: return 0.11
        case .drover: return 0.21
        case .stonemason: return -0.14
        case .tiler: return -0.06
        case .glassblower: return 0.07
        case .armourer: return -0.03
        case .apothecary: return 0.10
        }
    }

    /// Sums at the founding scale. The engine widens these as the house grows.
    var sumRange: ClosedRange<Int> {
        switch self {
        case .spiceFactor: return 90...370
        case .shipwright: return 100...390
        case .saltTrader: return 70...270
        case .grainFactor: return 60...245
        case .stonemason: return 55...235
        case .silkDyer: return 50...215
        case .woolWeaver: return 40...185
        case .vintner: return 45...205
        case .drover: return 35...155
        case .fuller: return 30...135
        case .tiler: return 30...130
        case .glassblower: return 35...155
        case .armourer: return 45...195
        case .apothecary: return 30...145
        }
    }

    var purposes: [String] {
        switch self {
        case .woolWeaver: return ["to buy raw fleece before the shearing", "to set up two more looms", "to pay the carders through winter"]
        case .silkDyer: return ["to buy kermes and alum", "to line new dye vats", "to settle a dyestuff account"]
        case .fuller: return ["to repair the fulling mill", "to lease a second tenter field", "to buy fuller's earth in bulk"]
        case .spiceFactor: return ["to buy a share of the incoming cargo", "to settle a factor's account overseas", "to hold pepper until the fair"]
        case .shipwright: return ["to lay a keel on speculation", "to buy seasoned oak and pitch", "to pay the caulkers for the season"]
        case .saltTrader: return ["to take up the salt pans this season", "to hire carts for the inland run", "to buy a share in the salt barge"]
        case .vintner: return ["to buy new casks before pressing", "to hold the vintage another year", "to replant the eastern slope"]
        case .grainFactor: return ["to buy grain ahead of the market", "to rent granary space", "to pay the threshers"]
        case .drover: return ["to buy yearlings for the autumn drive", "to pay the tolls on the mountain road", "to replace lost beasts"]
        case .stonemason: return ["to hire a gang for the chapel works", "to buy a season at the quarry", "to raise a crane and scaffold"]
        case .tiler: return ["to fire a larger kiln", "to buy clay rights by the river", "to pay for a cart and team"]
        case .glassblower: return ["to buy soda ash and fine sand", "to rebuild the furnace crown", "to take on two journeymen"]
        case .armourer: return ["to fill a commission for the watch", "to buy billets of good steel", "to set up a water hammer"]
        case .apothecary: return ["to buy simples before the fair", "to fit out a new still", "to settle an account with the herbalist"]
        }
    }
}

// MARK: - Standing of the applicant in the city

enum ApplicantStanding: String, Codable, CaseIterable {
    case unknown, poor, fair, good, esteemed

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .esteemed: return "Esteemed"
        }
    }

    /// Hidden contribution to the default log-odds.
    var hazard: Double {
        switch self {
        case .unknown: return 0.38
        case .poor: return 0.92
        case .fair: return 0.00
        case .good: return -0.42
        case .esteemed: return -0.82
        }
    }

    var order: Int {
        switch self {
        case .poor: return 0
        case .unknown: return 1
        case .fair: return 2
        case .good: return 3
        case .esteemed: return 4
        }
    }
}

// MARK: - Signals (cues)
//
// The player never sees these weights. They are fixed for the whole campaign and are
// meant to be inferred from the house's own ledger.

enum SignalCue: String, Codable, CaseIterable {
    // Favourable
    case guildEndorsement
    case repaidUsBefore
    case longEstablished
    case chapelContract
    case apprenticesKept
    // Adverse
    case debtsElsewhere
    case ledgerDisordered
    case consignmentOverdue
    case failedSeasons
    case inheritanceDispute
    case movedTwiceThisYear
    case defaultedOnUsBefore
    // Noise
    case rivalSpeaksIll
    case finelyDressed
    case magistratesNephew
    case arrivedAtFirstLight
    case starsAreFavourable
    case bringsGiftOfWine

    var label: String {
        switch self {
        case .guildEndorsement: return "Endorsed by the guild"
        case .repaidUsBefore: return "Repaid this house before"
        case .longEstablished: return "Workshop of twenty years"
        case .chapelContract: return "Holds a chapel commission"
        case .apprenticesKept: return "Keeps every apprentice on"
        case .debtsElsewhere: return "Owes money elsewhere in the city"
        case .ledgerDisordered: return "The ledger is in disorder"
        case .consignmentOverdue: return "A consignment is overdue"
        case .failedSeasons: return "Two seasons have gone badly"
        case .inheritanceDispute: return "Quarrels with kin over an estate"
        case .movedTwiceThisYear: return "Has moved workshop twice"
        case .defaultedOnUsBefore: return "Failed this house before"
        case .rivalSpeaksIll: return "Spoken ill of by a rival"
        case .finelyDressed: return "Comes finely dressed"
        case .magistratesNephew: return "Kin to a magistrate"
        case .arrivedAtFirstLight: return "Arrived at first light"
        case .starsAreFavourable: return "Says the stars are favourable"
        case .bringsGiftOfWine: return "Brings a gift of wine"
        }
    }

    /// Hidden weight on the default log-odds.
    var weight: Double {
        switch self {
        case .guildEndorsement: return -0.95
        case .repaidUsBefore: return -1.05
        case .longEstablished: return -0.55
        case .chapelContract: return -0.60
        case .apprenticesKept: return -0.35
        case .debtsElsewhere: return 0.90
        case .ledgerDisordered: return 0.72
        case .consignmentOverdue: return 0.78
        case .failedSeasons: return 0.66
        case .inheritanceDispute: return 0.45
        case .movedTwiceThisYear: return 0.40
        case .defaultedOnUsBefore: return 1.25
        case .rivalSpeaksIll, .finelyDressed, .magistratesNephew,
             .arrivedAtFirstLight, .starsAreFavourable, .bringsGiftOfWine:
            return 0.0
        }
    }

    /// Some cues bite far harder in one sector than in the others.
    func weight(inSector sector: HouseSector) -> Double {
        switch self {
        case .consignmentOverdue: return sector == .sea ? weight * 1.6 : weight
        case .failedSeasons: return sector == .land ? weight * 1.7 : weight
        case .chapelContract: return sector == .stone ? weight * 1.5 : weight
        default: return weight
        }
    }

    /// Cues that can only be attached to a returning borrower.
    var requiresHistory: Bool {
        self == .repaidUsBefore || self == .defaultedOnUsBefore
    }

    static var drawable: [SignalCue] {
        SignalCue.allCases.filter { !$0.requiresHistory }
    }
}

// MARK: - Pledges offered as collateral

enum PledgeKind: String, Codable, CaseIterable {
    case coinAndPlate
    case jewelry
    case guildBond
    case clothBales
    case shipShare
    case toolsOfTrade
    case houseDeed
    case landDeed

    var label: String {
        switch self {
        case .coinAndPlate: return "Silver plate"
        case .jewelry: return "A jewelled clasp"
        case .guildBond: return "A guild bond"
        case .clothBales: return "Bales of finished cloth"
        case .shipShare: return "A share in a hull"
        case .toolsOfTrade: return "The tools of the trade"
        case .houseDeed: return "A deed to a house"
        case .landDeed: return "A strip of land"
        }
    }

    /// What fraction of true value survives a forced sale.
    var liquidity: Double {
        switch self {
        case .coinAndPlate: return 0.92
        case .jewelry: return 0.84
        case .guildBond: return 0.80
        case .clothBales: return 0.72
        case .shipShare: return 0.50
        case .toolsOfTrade: return 0.55
        case .houseDeed: return 0.48
        case .landDeed: return 0.40
        }
    }

    var liquidityLabel: String {
        switch liquidity {
        case 0.8...: return "Sells at once"
        case 0.6..<0.8: return "Sells readily"
        case 0.47..<0.6: return "Slow to sell"
        default: return "Hard to sell"
        }
    }

    /// How much the applicant resents being asked for this. Subtracted from acceptance.
    var reluctance: Double {
        switch self {
        case .coinAndPlate: return 0.04
        case .jewelry: return 0.09
        case .guildBond: return 0.05
        case .clothBales: return 0.06
        case .shipShare: return 0.12
        case .toolsOfTrade: return 0.18
        case .houseDeed: return 0.16
        case .landDeed: return 0.13
        }
    }
}

struct Pledge: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: PledgeKind
    /// What the applicant claims it is worth — what the player sees.
    var statedValue: Int
    /// What it is really worth. Never shown before the pledge is sold.
    var trueValue: Int

    init(id: UUID = UUID(), kind: PledgeKind, statedValue: Int, trueValue: Int) {
        self.id = id
        self.kind = kind
        self.statedValue = statedValue
        self.trueValue = trueValue
    }

    /// Coin actually raised if this pledge is sold at the given efficiency.
    func recovery(efficiency: Double) -> Double {
        Double(trueValue) * kind.liquidity * efficiency
    }

    enum CodingKeys: String, CodingKey { case id, kind, statedValue, trueValue }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? box.decode(UUID.self, forKey: .id)) ?? UUID()
        kind = (try? box.decode(PledgeKind.self, forKey: .kind)) ?? .clothBales
        statedValue = (try? box.decode(Int.self, forKey: .statedValue)) ?? 0
        trueValue = (try? box.decode(Int.self, forKey: .trueValue)) ?? statedValue
    }
}

// MARK: - Cities

enum CityID: String, Codable, CaseIterable {
    case ardenza, portovaro, kelsburg, miralta

    var label: String {
        switch self {
        case .ardenza: return "Ardenza"
        case .portovaro: return "Portovaro"
        case .kelsburg: return "Kelsburg"
        case .miralta: return "Miralta"
        }
    }

    var blurb: String {
        switch self {
        case .ardenza: return "The home counter. A balanced street of every trade."
        case .portovaro: return "A harbour town. Sea ventures, large sums, large risks."
        case .kelsburg: return "Quarries and forges. Steady stone and craft work."
        case .miralta: return "Looms and vineyards. Cloth and land in equal measure."
        }
    }

    var openingCost: Int {
        switch self {
        case .ardenza: return 0
        case .portovaro: return 1600
        case .kelsburg: return 4200
        case .miralta: return 9000
        }
    }

    var weeklyUpkeep: Int {
        switch self {
        case .ardenza: return 4
        case .portovaro: return 14
        case .kelsburg: return 20
        case .miralta: return 28
        }
    }

    /// Relative frequency of each sector in this city's queue.
    var sectorMix: [HouseSector: Double] {
        switch self {
        case .ardenza: return [.cloth: 1.0, .sea: 0.7, .land: 1.0, .stone: 0.9, .craft: 1.0]
        case .portovaro: return [.cloth: 0.6, .sea: 2.6, .land: 0.4, .stone: 0.5, .craft: 0.8]
        case .kelsburg: return [.cloth: 0.5, .sea: 0.3, .land: 0.8, .stone: 2.2, .craft: 1.8]
        case .miralta: return [.cloth: 2.4, .sea: 0.4, .land: 2.0, .stone: 0.5, .craft: 0.7]
        }
    }
}

// MARK: - Instruments

enum InstrumentKind: String, Codable, CaseIterable {
    case loan, bill, commenda

    var label: String {
        switch self {
        case .loan: return "Loan"
        case .bill: return "Bill of Exchange"
        case .commenda: return "Commenda"
        }
    }

    var shortLabel: String {
        switch self {
        case .loan: return "Loan"
        case .bill: return "Bill"
        case .commenda: return "Share"
        }
    }

    var blurb: String {
        switch self {
        case .loan:
            return "You set a rate, a term, and which pledges you require. Interest accrues to the term."
        case .bill:
            return "You buy the debt at a discount and are paid the face value at maturity. Short, unsecured, guaranteed by a correspondent house, and thin."
        case .commenda:
            return "You put up the capital and take a share of what the venture earns. No interest, no pledges. The whole upside and the whole downside are yours to price."
        }
    }
}

// MARK: - Loan record

enum LoanStatus: String, Codable {
    case outstanding
    case repaidOnTime
    case repaidLate
    case repaidPartly
    case defaulted

    var label: String {
        switch self {
        case .outstanding: return "Outstanding"
        case .repaidOnTime: return "Repaid"
        case .repaidLate: return "Repaid late"
        case .repaidPartly: return "Part repaid"
        case .defaulted: return "Failed"
        }
    }

    var isResolved: Bool { self != .outstanding }
}

enum RecoveryChoice: String, Codable {
    case seized, composed

    var label: String {
        switch self {
        case .seized: return "Pledges seized"
        case .composed: return "Terms composed"
        }
    }
}

struct LoanRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var borrower: String
    var trade: TradeID
    var city: CityID
    var standing: ApplicantStanding
    var instrument: InstrumentKind
    var principal: Int
    /// Quarterly rate for a loan, discount for a bill, profit share for a commenda.
    var rate: Double
    var termWeeks: Int
    var openedWeek: Int
    var dueWeek: Int
    var pledges: [Pledge]
    /// The cues the player could see when pricing. Drives the ledger's signal study.
    var cuesSeen: [SignalCue]
    /// Everything the applicant actually carried. Revealed once the loan resolves.
    var cuesAll: [SignalCue]
    var baseHazard: Double
    var status: LoanStatus
    var resolvedWeek: Int?
    var cashOut: Int
    var cashIn: Int
    var recoveryChoice: RecoveryChoice?
    var awaitingRuling: Bool
    var wasExtended: Bool

    var sector: HouseSector { trade.sector }

    var profit: Int { cashIn - cashOut }

    /// Face value owed at maturity.
    var amountDue: Int {
        switch instrument {
        case .loan:
            return principal + Int((Double(principal) * rate * Double(termWeeks) / 13.0).rounded())
        case .bill:
            return principal
        case .commenda:
            return principal
        }
    }

    var interestDue: Int { amountDue - principal }

    init(id: UUID = UUID(),
         borrower: String,
         trade: TradeID,
         city: CityID,
         standing: ApplicantStanding,
         instrument: InstrumentKind,
         principal: Int,
         rate: Double,
         termWeeks: Int,
         openedWeek: Int,
         dueWeek: Int,
         pledges: [Pledge],
         cuesSeen: [SignalCue],
         cuesAll: [SignalCue],
         baseHazard: Double,
         status: LoanStatus = .outstanding,
         resolvedWeek: Int? = nil,
         cashOut: Int,
         cashIn: Int = 0,
         recoveryChoice: RecoveryChoice? = nil,
         awaitingRuling: Bool = false,
         wasExtended: Bool = false) {
        self.id = id
        self.borrower = borrower
        self.trade = trade
        self.city = city
        self.standing = standing
        self.instrument = instrument
        self.principal = principal
        self.rate = rate
        self.termWeeks = termWeeks
        self.openedWeek = openedWeek
        self.dueWeek = dueWeek
        self.pledges = pledges
        self.cuesSeen = cuesSeen
        self.cuesAll = cuesAll
        self.baseHazard = baseHazard
        self.status = status
        self.resolvedWeek = resolvedWeek
        self.cashOut = cashOut
        self.cashIn = cashIn
        self.recoveryChoice = recoveryChoice
        self.awaitingRuling = awaitingRuling
        self.wasExtended = wasExtended
    }

    enum CodingKeys: String, CodingKey {
        case id, borrower, trade, city, standing, instrument, principal, rate, termWeeks
        case openedWeek, dueWeek, pledges, cuesSeen, cuesAll, baseHazard, status
        case resolvedWeek, cashOut, cashIn, recoveryChoice, awaitingRuling, wasExtended
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? box.decode(UUID.self, forKey: .id)) ?? UUID()
        borrower = (try? box.decode(String.self, forKey: .borrower)) ?? "A borrower"
        trade = (try? box.decode(TradeID.self, forKey: .trade)) ?? .woolWeaver
        city = (try? box.decode(CityID.self, forKey: .city)) ?? .ardenza
        standing = (try? box.decode(ApplicantStanding.self, forKey: .standing)) ?? .fair
        instrument = (try? box.decode(InstrumentKind.self, forKey: .instrument)) ?? .loan
        principal = (try? box.decode(Int.self, forKey: .principal)) ?? 0
        rate = (try? box.decode(Double.self, forKey: .rate)) ?? 0.12
        termWeeks = (try? box.decode(Int.self, forKey: .termWeeks)) ?? 12
        openedWeek = (try? box.decode(Int.self, forKey: .openedWeek)) ?? 0
        dueWeek = (try? box.decode(Int.self, forKey: .dueWeek)) ?? 12
        pledges = (try? box.decode([Pledge].self, forKey: .pledges)) ?? []
        cuesSeen = (try? box.decode([SignalCue].self, forKey: .cuesSeen)) ?? []
        cuesAll = (try? box.decode([SignalCue].self, forKey: .cuesAll)) ?? []
        baseHazard = (try? box.decode(Double.self, forKey: .baseHazard)) ?? -1.8
        status = (try? box.decode(LoanStatus.self, forKey: .status)) ?? .outstanding
        resolvedWeek = try? box.decode(Int.self, forKey: .resolvedWeek)
        cashOut = (try? box.decode(Int.self, forKey: .cashOut)) ?? principal
        cashIn = (try? box.decode(Int.self, forKey: .cashIn)) ?? 0
        recoveryChoice = try? box.decode(RecoveryChoice.self, forKey: .recoveryChoice)
        awaitingRuling = (try? box.decode(Bool.self, forKey: .awaitingRuling)) ?? false
        wasExtended = (try? box.decode(Bool.self, forKey: .wasExtended)) ?? false
    }
}

// MARK: - Applicant

struct LoanApplicant: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var trade: TradeID
    var city: CityID
    var standing: ApplicantStanding
    var amount: Int
    var purpose: String
    var askedTerm: Int
    var pledges: [Pledge]
    /// All cues the applicant carries, already shuffled. The player sees only a prefix.
    var cues: [SignalCue]
    var visibleCount: Int
    /// Log-odds of failure before any terms are applied. Hidden.
    var baseHazard: Double
    /// Hidden appetite for a hard bargain.
    var pressure: Double

    var sector: HouseSector { trade.sector }
    var visibleCues: [SignalCue] { Array(cues.prefix(visibleCount)) }
    var hiddenCueCount: Int { max(0, cues.count - visibleCount) }
    var offeredPledgeValue: Int { pledges.reduce(0) { $0 + $1.statedValue } }

    enum CodingKeys: String, CodingKey {
        case id, name, trade, city, standing, amount, purpose, askedTerm
        case pledges, cues, visibleCount, baseHazard, pressure
    }

    init(id: UUID = UUID(),
         name: String,
         trade: TradeID,
         city: CityID,
         standing: ApplicantStanding,
         amount: Int,
         purpose: String,
         askedTerm: Int,
         pledges: [Pledge],
         cues: [SignalCue],
         visibleCount: Int,
         baseHazard: Double,
         pressure: Double) {
        self.id = id
        self.name = name
        self.trade = trade
        self.city = city
        self.standing = standing
        self.amount = amount
        self.purpose = purpose
        self.askedTerm = askedTerm
        self.pledges = pledges
        self.cues = cues
        self.visibleCount = visibleCount
        self.baseHazard = baseHazard
        self.pressure = pressure
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? box.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? box.decode(String.self, forKey: .name)) ?? "A stranger"
        trade = (try? box.decode(TradeID.self, forKey: .trade)) ?? .woolWeaver
        city = (try? box.decode(CityID.self, forKey: .city)) ?? .ardenza
        standing = (try? box.decode(ApplicantStanding.self, forKey: .standing)) ?? .fair
        amount = (try? box.decode(Int.self, forKey: .amount)) ?? 100
        purpose = (try? box.decode(String.self, forKey: .purpose)) ?? "for the trade"
        askedTerm = (try? box.decode(Int.self, forKey: .askedTerm)) ?? 12
        pledges = (try? box.decode([Pledge].self, forKey: .pledges)) ?? []
        cues = (try? box.decode([SignalCue].self, forKey: .cues)) ?? []
        visibleCount = (try? box.decode(Int.self, forKey: .visibleCount)) ?? 3
        baseHazard = (try? box.decode(Double.self, forKey: .baseHazard)) ?? -1.8
        pressure = (try? box.decode(Double.self, forKey: .pressure)) ?? 0
    }
}

/// A borrower the house has dealt with before.
struct Alumnus: Codable, Equatable {
    var name: String
    var trade: TradeID
    var city: CityID
    var honoured: Bool

    init(name: String, trade: TradeID, city: CityID, honoured: Bool) {
        self.name = name
        self.trade = trade
        self.city = city
        self.honoured = honoured
    }

    enum CodingKeys: String, CodingKey { case name, trade, city, honoured }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? box.decode(String.self, forKey: .name)) ?? "A borrower"
        trade = (try? box.decode(TradeID.self, forKey: .trade)) ?? .woolWeaver
        city = (try? box.decode(CityID.self, forKey: .city)) ?? .ardenza
        honoured = (try? box.decode(Bool.self, forKey: .honoured)) ?? true
    }
}

// MARK: - Terms the player sets

struct OfferTerms: Equatable {
    var instrument: InstrumentKind = .loan
    /// Quarterly interest for a loan, discount for a bill, profit share for a commenda.
    var rate: Double = 0.12
    var termWeeks: Int = 12
    var requiredPledgeIDs: Set<UUID> = []

    func requiredPledges(from applicant: LoanApplicant) -> [Pledge] {
        applicant.pledges.filter { requiredPledgeIDs.contains($0.id) }
    }
}

// MARK: - Market events

struct MarketEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var detail: String
    /// Empty means every sector.
    var sectors: [HouseSector]
    var hazardShift: Double
    var volumeShift: Int
    var startWeek: Int
    var endWeek: Int

    func affects(_ sector: HouseSector) -> Bool {
        sectors.isEmpty || sectors.contains(sector)
    }

    func isActive(onWeek week: Int) -> Bool {
        week >= startWeek && week <= endWeek
    }

    var sectorLabel: String {
        sectors.isEmpty ? "Every trade" : sectors.map { $0.label }.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, title, detail, sectors, hazardShift, volumeShift, startWeek, endWeek
    }

    init(id: UUID = UUID(), title: String, detail: String, sectors: [HouseSector],
         hazardShift: Double, volumeShift: Int, startWeek: Int, endWeek: Int) {
        self.id = id
        self.title = title
        self.detail = detail
        self.sectors = sectors
        self.hazardShift = hazardShift
        self.volumeShift = volumeShift
        self.startWeek = startWeek
        self.endWeek = endWeek
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? box.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? box.decode(String.self, forKey: .title)) ?? "A quiet season"
        detail = (try? box.decode(String.self, forKey: .detail)) ?? ""
        sectors = (try? box.decode([HouseSector].self, forKey: .sectors)) ?? []
        hazardShift = (try? box.decode(Double.self, forKey: .hazardShift)) ?? 0
        volumeShift = (try? box.decode(Int.self, forKey: .volumeShift)) ?? 0
        startWeek = (try? box.decode(Int.self, forKey: .startWeek)) ?? 0
        endWeek = (try? box.decode(Int.self, forKey: .endWeek)) ?? 0
    }
}

// MARK: - Week report entries

enum WeekNoteKind: String, Codable {
    case repaid, late, partial, failed, event, upkeep, opened, walked, ruling
}

struct WeekNote: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: WeekNoteKind
    var headline: String
    var detail: String
    var amount: Int

    init(id: UUID = UUID(), kind: WeekNoteKind, headline: String, detail: String, amount: Int = 0) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey { case id, kind, headline, detail, amount }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? box.decode(UUID.self, forKey: .id)) ?? UUID()
        kind = (try? box.decode(WeekNoteKind.self, forKey: .kind)) ?? .event
        headline = (try? box.decode(String.self, forKey: .headline)) ?? ""
        detail = (try? box.decode(String.self, forKey: .detail)) ?? ""
        amount = (try? box.decode(Int.self, forKey: .amount)) ?? 0
    }
}

// MARK: - Upgrades

struct HouseStaff: Codable, Equatable {
    var clerkTier: Int = 0     // 0...3 — how many cues the counter can read
    var assayerTier: Int = 0   // 0...2 — how honest the stated pledge values are
    var notaryTier: Int = 0    // 0...2 — recovery efficiency and standing cost of seizure
    var correspondent: Bool = false

    var revealCapacity: Int { 2 + clerkTier }          // 2, 3, 4, 5
    var appraisalError: Double {                       // +/- fraction on stated pledge value
        switch assayerTier {
        case 0: return 0.30
        case 1: return 0.15
        default: return 0.06
        }
    }
    var seizureEfficiency: Double {
        switch notaryTier {
        case 0: return 0.85
        case 1: return 0.92
        default: return 0.97
        }
    }
    var seizureStandingCost: Double {
        switch notaryTier {
        case 0: return 3.2
        case 1: return 2.4
        default: return 1.7
        }
    }
    var weeklyWages: Int {
        var total = 0
        switch clerkTier {
        case 1: total += 6
        case 2: total += 11
        case 3: total += 18
        default: break
        }
        switch assayerTier {
        case 1: total += 5
        case 2: total += 9
        default: break
        }
        switch notaryTier {
        case 1: total += 6
        case 2: total += 12
        default: break
        }
        if correspondent { total += 8 }
        return total
    }

    enum CodingKeys: String, CodingKey { case clerkTier, assayerTier, notaryTier, correspondent }

    init() {}

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        // Clamped, not merely defaulted: these tiers index fixed wage tables in the UI,
        // so an out-of-range value from a damaged save would be a crash, not a glitch.
        clerkTier = min(3, max(0, (try? box.decode(Int.self, forKey: .clerkTier)) ?? 0))
        assayerTier = min(2, max(0, (try? box.decode(Int.self, forKey: .assayerTier)) ?? 0))
        notaryTier = min(2, max(0, (try? box.decode(Int.self, forKey: .notaryTier)) ?? 0))
        correspondent = (try? box.decode(Bool.self, forKey: .correspondent)) ?? false
    }
}

// MARK: - Numbers the counter needs everywhere

enum LendingMath {
    static func logistic(_ z: Double) -> Double {
        1.0 / (1.0 + exp(-z))
    }

    static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}
