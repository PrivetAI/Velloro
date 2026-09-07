import Foundation

/// Everything the hidden model needs to price a single week.
struct CounterContext {
    var week: Int
    var standing: Double
    var staff: HouseStaff
    var openCities: [CityID]
    var events: [MarketEvent]
    var alumni: [Alumnus]
    var concentrationPenalty: Double
    /// How large the sums at the counter have grown with the house.
    var sumScale: Double

    init(week: Int, standing: Double, staff: HouseStaff, openCities: [CityID],
         events: [MarketEvent], alumni: [Alumnus], concentrationPenalty: Double,
         sumScale: Double = 1.0) {
        self.week = week
        self.standing = standing
        self.staff = staff
        self.openCities = openCities
        self.events = events
        self.alumni = alumni
        self.concentrationPenalty = concentrationPenalty
        self.sumScale = sumScale
    }
}

/// The resolution of one matured claim.
struct ClaimResolution {
    var status: LoanStatus
    var cashIn: Int
    var extendUntil: Int?
    var standingDelta: Double
    var note: String
}

enum CounterEngine {

    // MARK: - Tuning constants (the hidden model)

    static let hazardFloor: Double = -2.35
    static let termHazardPerWeek: Double = 0.030
    static let rateHazardSlope: Double = 1.80
    static let rateHazardKnee: Double = 0.20
    static let uncoveredHazard: Double = 0.85
    static let sizeHazardSlope: Double = 0.30
    static let billGuaranteeRelief: Double = 0.55
    static let billGuaranteeRecovery: Double = 0.55
    static let performingOnTimeShare: Double = 0.78
    static let distressPartialShare: Double = 0.40
    static let courtDustOnSeizure: Double = 0.06
    static let courtDustOnComposition: Double = 0.20
    static let compositionEfficiencyFactor: Double = 0.35

    static let rateBounds: ClosedRange<Double> = 0.040...0.480
    static let discountBounds: ClosedRange<Double> = 0.010...0.120
    static let shareBounds: ClosedRange<Double> = 0.150...0.750
    static let termBounds: ClosedRange<Int> = 4...26
    static let billTermBounds: ClosedRange<Int> = 4...8

    // MARK: - Names

    private static let forenames = [
        "Aldo", "Bartolo", "Cosimo", "Domenico", "Ercole", "Filippo", "Gherardo",
        "Iacopo", "Lorenzo", "Matteo", "Niccolo", "Orso", "Piero", "Rinaldo",
        "Salvestro", "Taddeo", "Ubaldo", "Vieri", "Zanobi", "Benedetta", "Caterina",
        "Ginevra", "Lucrezia", "Margherita", "Nanna", "Selvaggia", "Tessa", "Bianca",
        "Fiammetta", "Isotta", "Guido", "Marsilio", "Antonio", "Giuliano"
    ]

    private static let surnames = [
        "Alberti", "Baroncelli", "Corsini", "Dietisalvi", "Ferrantini", "Guasconi",
        "Lenzi", "Manetti", "Nerli", "Orlandini", "Peruzzi", "Quaratesi", "Rucellai",
        "Serristori", "Tornabuoni", "Uzzano", "Valori", "Zati", "Bardi", "Cavalcanti",
        "Gondi", "Martelli", "Pandolfini", "Ridolfi", "Soderini", "Vettori", "Altoviti",
        "Bencivenni", "Della Stufa", "Machiavelli"
    ]

    static func makeName(_ rng: inout CounterRandom) -> String {
        "\(rng.choose(forenames)) \(rng.choose(surnames))"
    }

    // MARK: - Applicant generation

    static func weeklyIntake(context: CounterContext) -> Int {
        let volumeShift = context.events
            .filter { $0.isActive(onWeek: context.week) }
            .reduce(0) { $0 + $1.volumeShift }
        let base = 3 + (context.openCities.count - 1) + Int(context.standing / 18.0)
        return max(2, min(10, base + volumeShift))
    }

    static func generateQueue(context: CounterContext, rng: inout CounterRandom) -> [LoanApplicant] {
        let count = weeklyIntake(context: context)
        var made: [LoanApplicant] = []
        made.reserveCapacity(count)
        for _ in 0..<count {
            made.append(generateApplicant(context: context, rng: &rng))
        }
        return made
    }

    static func generateApplicant(context: CounterContext, rng: inout CounterRandom) -> LoanApplicant {
        // A returning face, sometimes.
        var alumnus: Alumnus? = nil
        if !context.alumni.isEmpty, rng.chance(0.20) {
            alumnus = context.alumni[rng.whole(0, context.alumni.count - 1)]
        }

        let city = alumnus?.city ?? pickCity(context: context, rng: &rng)
        let trade = alumnus?.trade ?? pickTrade(city: city, rng: &rng)

        // Temperament: negative is a sound borrower. Never shown, and only weakly
        // reflected in the visible standing, so the cues carry the real information.
        var temperament = rng.normal() - (context.standing - 50.0) / 50.0 * 0.55
        if let past = alumnus { temperament += past.honoured ? -0.55 : 0.55 }

        let standing = pickStanding(temperament: temperament, rng: &rng)

        let scale = LendingMath.clamp(context.sumScale, 0.30, 4.5)
        let range = trade.sumRange
        let low = max(15, Int(Double(range.lowerBound) * scale))
        let high = max(low + 10, Int(Double(range.upperBound) * scale))
        var amount = rng.whole(low, high)
        amount = max(15, Int((Double(amount) / 5.0).rounded()) * 5)

        var cues: [SignalCue] = []
        if let past = alumnus {
            cues.append(past.honoured ? .repaidUsBefore : .defaultedOnUsBefore)
        }
        cues.append(contentsOf: drawCues(count: rng.whole(2, 5), temperament: temperament, rng: &rng))

        let pledges = makePledges(amount: amount, standing: standing,
                                  appraisalError: context.staff.appraisalError, rng: &rng)

        var hazard = hazardFloor + trade.hazard + standing.hazard
        for cue in cues { hazard += cue.weight(inSector: trade.sector) }
        hazard += sizeHazardSlope * sizeHazard(amount: amount, scale: scale)

        let askedTerm = [6, 8, 10, 12, 13, 16, 20, 26][rng.whole(0, 7)]
        let visible = min(cues.count, max(1, context.staff.revealCapacity))

        return LoanApplicant(
            name: alumnus?.name ?? makeName(&rng),
            trade: trade,
            city: city,
            standing: standing,
            amount: amount,
            purpose: rng.choose(trade.purposes),
            askedTerm: askedTerm,
            pledges: pledges,
            cues: cues,
            visibleCount: visible,
            baseHazard: hazard,
            pressure: rng.span(-0.020, 0.140)
        )
    }

    /// Size risk is judged against what a sum means at the current scale of the house,
    /// so a grown house does not see every applicant as large.
    static func sizeHazard(amount: Int, scale: Double) -> Double {
        let normalized = Double(amount) / max(0.30, scale)
        return LendingMath.clamp((normalized - 130.0) / 140.0, -1.0, 1.6)
    }

    /// The scale of business a house of this size attracts.
    static func sumScale(forWorth worth: Int) -> Double {
        LendingMath.clamp(pow(max(200.0, Double(worth)) / 2000.0, 0.62), 0.30, 4.5)
    }

    private static func pickCity(context: CounterContext, rng: inout CounterRandom) -> CityID {
        guard context.openCities.count > 1 else { return context.openCities.first ?? .ardenza }
        // The home counter still carries the most traffic.
        var weights: [Double] = []
        for city in context.openCities { weights.append(city == .ardenza ? 1.6 : 1.0) }
        return rng.chooseWeighted(context.openCities, weights)
    }

    private static func pickTrade(city: CityID, rng: inout CounterRandom) -> TradeID {
        let mix = city.sectorMix
        let all = TradeID.allCases
        let weights = all.map { mix[$0.sector] ?? 1.0 }
        return rng.chooseWeighted(all, weights)
    }

    private static func pickStanding(temperament: Double, rng: inout CounterRandom) -> ApplicantStanding {
        let goodness = LendingMath.clamp(-temperament, -2.4, 2.4)
        let ladder: [(ApplicantStanding, Double)] = [
            (.poor, -1.40), (.unknown, -0.50), (.fair, 0.20), (.good, 1.00), (.esteemed, 1.80)
        ]
        let options = ladder.map { $0.0 }
        let weights = ladder.map { entry -> Double in
            let gap = entry.1 - goodness
            return exp(-(gap * gap) / 1.45) + 0.10
        }
        return rng.chooseWeighted(options, weights)
    }

    private static func drawCues(count: Int, temperament: Double, rng: inout CounterRandom) -> [SignalCue] {
        var pool = SignalCue.drawable
        var picked: [SignalCue] = []
        let tilt = LendingMath.clamp(temperament, -2.2, 2.2)
        for _ in 0..<count {
            guard !pool.isEmpty else { break }
            let favourable = exp(-tilt * 0.80)
            let adverse = exp(tilt * 0.80)
            // The chance of drawing an EMPTY remark must not vary with temperament, or
            // the noise cues quietly become informative by displacement and the ledger
            // teaches a rule that is not there. Scaling noise to the mean signal weight
            // holds its share of the draw constant at every temperament.
            let signalMean = (5.0 * favourable + 6.0 * adverse) / 11.0
            let empty = 1.45 * signalMean
            let weights = pool.map { cue -> Double in
                if cue.weight < -0.001 { return favourable }
                if cue.weight > 0.001 { return adverse }
                return empty
            }
            let choice = rng.chooseWeighted(pool, weights)
            picked.append(choice)
            pool.removeAll { $0 == choice }
        }
        // Which cues stay hidden must not be predictable from their order.
        for index in stride(from: picked.count - 1, to: 0, by: -1) {
            let swap = rng.whole(0, index)
            picked.swapAt(index, swap)
        }
        return picked
    }

    private static func makePledges(amount: Int,
                                    standing: ApplicantStanding,
                                    appraisalError: Double,
                                    rng: inout CounterRandom) -> [Pledge] {
        if rng.chance(0.10) { return [] }

        var coverage = rng.span(0.20, 0.95)
        switch standing {
        case .esteemed: coverage += 0.22
        case .good: coverage += 0.11
        case .poor: coverage -= 0.10
        case .unknown: coverage -= 0.05
        case .fair: break
        }
        coverage = LendingMath.clamp(coverage, 0.06, 1.30)

        var count = 1
        if rng.chance(0.45) { count += 1 }
        if rng.chance(0.18) { count += 1 }

        var kinds = PledgeKind.allCases
        var shares: [Double] = []
        for _ in 0..<count { shares.append(rng.span(0.4, 1.0)) }
        let shareTotal = shares.reduce(0, +)
        let pledgedTotal = Double(amount) * coverage

        var made: [Pledge] = []
        for index in 0..<count {
            guard !kinds.isEmpty else { break }
            let kind = kinds[rng.whole(0, kinds.count - 1)]
            kinds.removeAll { $0 == kind }
            let trueValue = max(5, Int((pledgedTotal * shares[index] / shareTotal).rounded()))
            let skew = rng.span(-appraisalError, appraisalError)
            let stated = max(5, Int((Double(trueValue) * (1.0 + skew)).rounded()))
            made.append(Pledge(kind: kind, statedValue: stated, trueValue: trueValue))
        }
        return made
    }

    // MARK: - Hazard given terms

    /// Extra log-odds contributed by the terms. The single definition used both when the
    /// player is pricing and when the claim actually resolves, so the two cannot drift.
    static func termsHazard(instrument: InstrumentKind,
                            rate: Double,
                            termWeeks: Int,
                            pledgedTrueValue: Int,
                            principal: Int) -> Double {
        let ageing = termHazardPerWeek * Double(termWeeks - 12)
        switch instrument {
        case .loan:
            let trueCover = Double(pledgedTrueValue) / Double(max(1, principal))
            return ageing
                + rateHazardSlope * max(0, rate - rateHazardKnee)
                + uncoveredHazard * (1.0 - min(1.0, trueCover))
        case .bill:
            return ageing - billGuaranteeRelief
        case .commenda:
            return ageing
        }
    }

    static func termsHazard(applicant: LoanApplicant, terms: OfferTerms) -> Double {
        let required = terms.requiredPledges(from: applicant)
        return termsHazard(instrument: terms.instrument,
                           rate: terms.rate,
                           termWeeks: terms.termWeeks,
                           pledgedTrueValue: required.reduce(0) { $0 + $1.trueValue },
                           principal: applicant.amount)
    }

    static func termsHazard(_ loan: LoanRecord) -> Double {
        termsHazard(instrument: loan.instrument,
                    rate: loan.rate,
                    termWeeks: loan.termWeeks,
                    pledgedTrueValue: loan.pledges.reduce(0) { $0 + $1.trueValue },
                    principal: loan.principal)
    }

    static func hazardShift(sector: HouseSector, week: Int, events: [MarketEvent]) -> Double {
        events.reduce(0.0) { total, event in
            (event.isActive(onWeek: week) && event.affects(sector)) ? total + event.hazardShift : total
        }
    }

    /// True probability the claim goes bad. The player never sees this number.
    static func trueDistressOdds(applicant: LoanApplicant,
                                 terms: OfferTerms,
                                 week: Int,
                                 events: [MarketEvent],
                                 concentration: Double) -> Double {
        let z = applicant.baseHazard
            + termsHazard(applicant: applicant, terms: terms)
            + concentration
            + hazardShift(sector: applicant.sector, week: week, events: events)
        return LendingMath.logistic(z)
    }

    // MARK: - Will they take it?

    /// The rate the applicant is quietly prepared to pay.
    static func reservationRate(_ applicant: LoanApplicant) -> Double {
        let base = LendingMath.logistic(applicant.baseHazard)
        return 0.215 + 0.500 * base + applicant.pressure
    }

    static func reservationDiscount(_ applicant: LoanApplicant) -> Double {
        let base = LendingMath.logistic(applicant.baseHazard)
        return 0.020 + 0.100 * base + applicant.pressure * 0.5
    }

    static func reservationShare(_ applicant: LoanApplicant) -> Double {
        let base = LendingMath.logistic(applicant.baseHazard)
        return 0.40 + 0.38 * base + applicant.pressure * 1.4
    }

    static func acceptanceOdds(applicant: LoanApplicant, terms: OfferTerms) -> Double {
        var odds: Double
        switch terms.instrument {
        case .loan:
            let gap = terms.rate - reservationRate(applicant)
            odds = gap <= 0 ? 0.96 : 0.96 * exp(-gap / 0.050)
        case .bill:
            let gap = terms.rate - reservationDiscount(applicant)
            odds = gap <= 0 ? 0.94 : 0.94 * exp(-gap / 0.020)
        case .commenda:
            let gap = terms.rate - reservationShare(applicant)
            odds = gap <= 0 ? 0.93 : 0.93 * exp(-gap / 0.090)
        }

        if terms.termWeeks < applicant.askedTerm {
            odds *= max(0.35, 1.0 - 0.050 * Double(applicant.askedTerm - terms.termWeeks))
        }

        if terms.instrument == .loan {
            let reluctance = terms.requiredPledges(from: applicant).reduce(0.0) { $0 + $1.kind.reluctance }
            odds *= max(0.30, 1.0 - reluctance)
        }

        return LendingMath.clamp(odds, 0.0, 0.98)
    }

    /// A coarse public reading of the acceptance odds. Never a raw percentage.
    static func acceptanceReading(_ odds: Double) -> String {
        switch odds {
        case 0.80...: return "Taken gladly"
        case 0.58..<0.80: return "Very likely to be taken"
        case 0.36..<0.58: return "It may be taken"
        case 0.16..<0.36: return "Likely to be refused"
        default: return "Will be refused"
        }
    }

    // MARK: - Concentration

    /// Herfindahl over outstanding principal by sector, converted to extra log-odds.
    static func concentrationPenalty(outstanding: [LoanRecord]) -> Double {
        let live = outstanding.filter { $0.status == .outstanding }
        let total = Double(live.reduce(0) { $0 + $1.principal })
        guard total > 0, live.count > 0 else { return 0 }
        var buckets: [HouseSector: Double] = [:]
        for loan in live {
            buckets[loan.sector, default: 0] += Double(loan.principal)
        }
        let hhi = buckets.values.reduce(0.0) { $0 + ($1 / total) * ($1 / total) }
        let raw = max(0.0, hhi - 0.34) * 2.40
        let ramp = min(1.0, Double(live.count) / 5.0)
        return raw * ramp
    }

    static func concentrationIndex(outstanding: [LoanRecord]) -> Double {
        let live = outstanding.filter { $0.status == .outstanding }
        let total = Double(live.reduce(0) { $0 + $1.principal })
        guard total > 0 else { return 0 }
        var buckets: [HouseSector: Double] = [:]
        for loan in live { buckets[loan.sector, default: 0] += Double(loan.principal) }
        return buckets.values.reduce(0.0) { $0 + ($1 / total) * ($1 / total) }
    }

    // MARK: - Resolution

    /// Rolls a matured claim. `extendUntil` non-nil means the debtor is late, not lost.
    static func resolve(loan: LoanRecord,
                        staff: HouseStaff,
                        events: [MarketEvent],
                        concentration: Double,
                        rng: inout CounterRandom) -> ClaimResolution {
        let shift = hazardShift(sector: loan.sector, week: loan.dueWeek, events: events)

        if loan.instrument == .commenda {
            let base = LendingMath.logistic(loan.baseHazard + termsHazard(loan) + concentration + shift)
            let mu = 0.30 - 1.30 * base
            let sigma = 0.26 + 0.55 * base
            let venture = LendingMath.clamp(mu + sigma * rng.normal(), -1.0, 2.2)
            let payout: Double = venture >= 0
                ? Double(loan.principal) * (1.0 + loan.rate * venture)
                : Double(loan.principal) * (1.0 + venture)
            let cash = max(0, Int(payout.rounded()))
            if venture >= 0.02 {
                return ClaimResolution(status: .repaidOnTime, cashIn: cash, extendUntil: nil,
                                       standingDelta: 0.30,
                                       note: "The venture returned a profit and the house took its share.")
            } else if venture > -0.35 {
                return ClaimResolution(status: .repaidPartly, cashIn: cash, extendUntil: nil,
                                       standingDelta: -0.20,
                                       note: "The venture barely broke even. The capital came back thinner.")
            } else {
                return ClaimResolution(status: .defaulted, cashIn: cash, extendUntil: nil,
                                       standingDelta: -0.60,
                                       note: "The venture failed. There are no pledges to seize on a commenda.")
            }
        }

        let odds = LendingMath.logistic(loan.baseHazard + termsHazard(loan) + concentration + shift)
        let due = loan.amountDue

        if !rng.chance(odds) {
            if loan.wasExtended || rng.chance(performingOnTimeShare) {
                let cash = loan.wasExtended
                    ? loan.principal + Int((Double(loan.interestDue) * 0.90).rounded())
                    : due
                return ClaimResolution(status: loan.wasExtended ? .repaidLate : .repaidOnTime,
                                       cashIn: cash, extendUntil: nil,
                                       standingDelta: loan.wasExtended ? 0.10 : 0.30,
                                       note: loan.wasExtended
                                        ? "Late, but paid in full less a little interest forgiven."
                                        : "Paid on the day, in full.")
            }
            let slip = rng.whole(2, 6)
            return ClaimResolution(status: .outstanding, cashIn: 0,
                                   extendUntil: loan.dueWeek + slip, standingDelta: 0,
                                   note: "Asks for \(slip) more weeks. The coin is not lost, only slow.")
        }

        if rng.chance(distressPartialShare) {
            let paid = Int((Double(due) * rng.span(0.42, 0.85)).rounded())
            return ClaimResolution(status: .repaidPartly, cashIn: paid, extendUntil: nil,
                                   standingDelta: -0.45,
                                   note: "Only part could be paid. The pledges go back.")
        }

        if loan.instrument == .bill {
            let cover = Int((Double(loan.principal) * billGuaranteeRecovery).rounded())
            return ClaimResolution(status: .defaulted, cashIn: cover, extendUntil: nil,
                                   standingDelta: -0.30,
                                   note: "The bill was protested. The correspondent house covered part of it.")
        }

        return ClaimResolution(status: .defaulted, cashIn: 0, extendUntil: nil, standingDelta: 0,
                               note: "The debt cannot be met. The house must decide what to do with the pledges.")
    }

    /// Coin raised and standing paid when the house rules on a failed loan.
    static func recovery(for loan: LoanRecord, choice: RecoveryChoice, staff: HouseStaff) -> (cash: Int, standing: Double) {
        let due = Double(loan.amountDue)
        switch choice {
        case .seized:
            let sale = loan.pledges.reduce(0.0) { $0 + $1.recovery(efficiency: staff.seizureEfficiency) }
            let court = Double(loan.principal) * courtDustOnSeizure
            return (Int(min(sale + court, due).rounded()), -staff.seizureStandingCost)
        case .composed:
            let sale = loan.pledges.reduce(0.0) {
                $0 + $1.recovery(efficiency: staff.seizureEfficiency * compositionEfficiencyFactor)
            }
            let goodwill = Double(loan.principal) * courtDustOnComposition
            return (Int(min(sale + goodwill, due).rounded()), 1.8)
        }
    }

    // MARK: - Events

    static func eventTable(week: Int, rng: inout CounterRandom) -> MarketEvent {
        let span = rng.whole(5, 12)
        let table: [(String, String, [HouseSector], Double, Int)] = [
            ("The harvest fails in the Vale",
             "Grain is dear and the country debtors are stretched. Land trades will struggle to pay.",
             [.land], 0.85, 0),
            ("A levy is laid on the guilds",
             "The city demands coin for the war chest. Every workshop is lighter by a third.",
             [], 0.35, 0),
            ("A new route opens past the cape",
             "Cargoes come home faster and fuller. Sea ventures are unusually sound this season.",
             [.sea], -0.55, 1),
            ("Fever in the eastern quarter",
             "Workshops stand half empty. Fewer come to the counter, and those who do are pressed.",
             [], 0.50, -1),
            ("The chapel works are commissioned",
             "Stone and its trades have steady money from the chapter for a year.",
             [.stone], -0.65, 1),
            ("A sumptuary law is proclaimed",
             "Fine cloth may not be worn in public. The looms have nowhere to sell.",
             [.cloth], 0.70, 0),
            ("The mint debases the silver",
             "Coin buys less than it did. Every debtor finds the obligation heavier.",
             [], 0.28, 0),
            ("Corsairs are sighted off the headland",
             "Hulls sit in the roads rather than sail. Sea money is stuck.",
             [.sea], 0.80, 0),
            ("The great fair opens at Portovaro",
             "Everyone has somewhere to sell. Trade is brisk and coin moves.",
             [], -0.30, 2),
            ("A quarry seam runs out",
             "The masons must cart stone from further off, and their margins vanish.",
             [.stone], 0.62, 0),
            ("Frost splits the vines",
             "The vintners lose a year and the drovers lose their feed.",
             [.land], 0.72, 0),
            ("A rival house calls in its loans",
             "Borrowers arrive at our counter already squeezed by somebody else.",
             [], 0.40, 2),
            ("Wool arrives cheap from the north",
             "The cloth trades buy their raw stock for half what they budgeted.",
             [.cloth], -0.50, 1),
            ("An armoury contract is let",
             "The craft workshops have a year of certain work.",
             [.craft], -0.55, 0),
            ("Charcoal doubles in price",
             "Every furnace in the city is burning money.",
             [.craft], 0.58, 0)
        ]
        let entry = table[rng.whole(0, table.count - 1)]
        return MarketEvent(title: entry.0, detail: entry.1, sectors: entry.2,
                           hazardShift: entry.3, volumeShift: entry.4,
                           startWeek: week, endWeek: week + span)
    }
}
