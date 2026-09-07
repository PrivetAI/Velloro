import SwiftUI

struct HouseView: View {
    @ObservedObject var house: HouseLedger

    var body: some View {
        CounterPage(title: "The House",
                    subtitle: house.houseName) {
            standingCard
            staffSection
            instrumentSection
            branchSection
        }
    }

    // MARK: - Standing

    private var standingCard: some View {
        CounterCard {
            HStack(alignment: .center, spacing: 12) {
                Glyph(shape: StandingGlyph(), size: 26, color: Ink.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Standing in the cities")
                        .font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(standingWord)
                        .font(Quill.title(20)).foregroundColor(Ink.burgundy)
                }
                Spacer()
                Text("\(Int(house.standing.rounded()))")
                    .font(Quill.numeral(26)).foregroundColor(Ink.text)
            }
            CounterBar(fraction: house.standing / 100.0, fill: Ink.burgundy)
            Text("A house spoken of well is brought better business and more of it. Seizing pledges recovers coin and costs standing; composing terms does the reverse.")
                .font(Quill.body(12)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Ink.rule).frame(height: 1)
            CounterStatRow(label: "Applicants expected each week",
                           value: "\(CounterEngine.weeklyIntake(context: intakeContext))")
            CounterStatRow(label: "Wages and rent each week", value: Tally.florins(house.weeklyUpkeep))
            CounterStatRow(label: "Paid out in upkeep so far", value: Tally.florins(house.save.lifetimeUpkeep))
            CounterStatRow(label: "Greatest worth reached", value: Tally.florins(house.save.peakWorth))
        }
    }

    private var intakeContext: CounterContext {
        CounterContext(week: house.week, standing: house.standing, staff: house.staff,
                       openCities: house.openCities, events: house.events,
                       alumni: [], concentrationPenalty: 0, sumScale: 1)
    }

    private var standingWord: String {
        switch house.standing {
        case ..<20: return "Feared and avoided"
        case 20..<40: return "Poorly spoken of"
        case 40..<60: return "Known well enough"
        case 60..<80: return "Well regarded"
        default: return "The first house in the city"
        }
    }

    // MARK: - Staff

    private var staffSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "Those who serve the counter")
            hireCard(title: "Clerk of the counter",
                     detail: "Reads what the city says of an applicant. Each clerk you add uncovers one more matter before you set terms.",
                     level: house.staff.clerkTier, maxLevel: 3,
                     effect: "Now reading \(house.staff.revealCapacity) matters per applicant",
                     cost: house.staff.clerkTier < 3 ? HouseLedger.clerkCosts[house.staff.clerkTier] : nil,
                     wage: [0, 6, 11, 18][house.staff.clerkTier],
                     action: house.hireClerk)
            hireCard(title: "Assayer of pledges",
                     detail: "Weighs what a pledge is truly worth. Without one you have only the borrower's own word on the value.",
                     level: house.staff.assayerTier, maxLevel: 2,
                     effect: "Stated values now within \(Tally.percent(house.staff.appraisalError)) of the truth",
                     cost: house.staff.assayerTier < 2 ? HouseLedger.assayerCosts[house.staff.assayerTier] : nil,
                     wage: [0, 5, 9][house.staff.assayerTier],
                     action: house.hireAssayer)
            hireCard(title: "Notary of the house",
                     detail: "Draws the instruments and presses claims in the courts. Raises what a forced sale returns and softens the ill will it brings.",
                     level: house.staff.notaryTier, maxLevel: 2,
                     effect: "Forced sale returns \(Tally.percent(house.staff.seizureEfficiency)) of value",
                     cost: house.staff.notaryTier < 2 ? HouseLedger.notaryCosts[house.staff.notaryTier] : nil,
                     wage: [0, 6, 12][house.staff.notaryTier],
                     action: house.hireNotary)
            hireCard(title: "Correspondent abroad",
                     detail: "A friendly house in a distant port that will honour your bills. Raises the sum a bill of exchange may carry.",
                     level: house.staff.correspondent ? 1 : 0, maxLevel: 1,
                     effect: "Bills up to \(Tally.florins(house.billCeiling))",
                     cost: house.staff.correspondent ? nil : HouseLedger.correspondentCost,
                     wage: house.staff.correspondent ? 8 : 0,
                     action: house.engageCorrespondent)
        }
    }

    private func hireCard(title: String, detail: String, level: Int, maxLevel: Int,
                          effect: String, cost: Int?, wage: Int,
                          action: @escaping () -> Void) -> some View {
        CounterCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Quill.heading(15)).foregroundColor(Ink.text)
                    Text(pips(level: level, max: maxLevel))
                        .font(Quill.label(11)).foregroundColor(Ink.gold)
                }
                Spacer(minLength: 8)
                if wage > 0 {
                    Text("\(wage) fl/wk").font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                }
            }
            Text(detail)
                .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(effect).font(Quill.label(11)).foregroundColor(Ink.burgundy)
            if let cost = cost {
                CounterButton(title: house.cash >= cost ? "Engage for \(Tally.florins(cost))"
                                                        : "Needs \(Tally.florins(cost))",
                              weight: .solid, enabled: house.cash >= cost, action: action)
            } else {
                Text("Nothing further to add here.")
                    .font(Quill.label(11)).foregroundColor(Ink.textFaint)
            }
        }
    }

    private func pips(level: Int, max: Int) -> String {
        guard max > 0 else { return "" }
        var text = ""
        for index in 0..<max { text += index < level ? "\u{25C6} " : "\u{25C7} " }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Instruments

    private var instrumentSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "Instruments open to you")
            ForEach(InstrumentKind.allCases, id: \.self) { kind in
                let open = house.unlockedInstruments.contains(kind)
                CounterCard(tint: open ? Ink.card : Ink.parchmentDim) {
                    HStack {
                        Text(kind.label).font(Quill.heading(15))
                            .foregroundColor(open ? Ink.text : Ink.textFaint)
                        Spacer()
                        CounterTag(text: open ? "In use" : "Not yet",
                                   fill: open ? Ink.good.opacity(0.15) : Ink.parchmentDim,
                                   stroke: open ? Ink.good.opacity(0.5) : Ink.cardEdge,
                                   textColor: open ? Ink.good : Ink.textFaint)
                    }
                    Text(kind.blurb)
                        .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !open {
                        Text(unlockNote(for: kind))
                            .font(Quill.label(11)).foregroundColor(Ink.caution)
                    }
                }
            }
        }
    }

    private func unlockNote(for kind: InstrumentKind) -> String {
        switch kind {
        case .loan: return ""
        case .bill: return "Opens once the house has been worth 2,800 fl. Highest so far: \(Tally.florins(house.save.peakWorth))."
        case .commenda: return "Opens once the house has been worth 6,000 fl. Highest so far: \(Tally.florins(house.save.peakWorth))."
        }
    }

    // MARK: - Branches

    private var branchSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "Counters", note: "\(house.openCities.count) of \(CityID.allCases.count)")
            ForEach(CityID.allCases, id: \.self) { city in
                let open = house.openCities.contains(city)
                CounterCard(tint: open ? Ink.card : Ink.parchmentDim) {
                    HStack {
                        Glyph(shape: HouseGlyph(), size: 18, color: open ? Ink.burgundy : Ink.textFaint)
                        Text(city.label).font(Quill.heading(15))
                            .foregroundColor(open ? Ink.text : Ink.textFaint)
                        Spacer()
                        Text("\(city.weeklyUpkeep) fl/wk")
                            .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                    }
                    Text(city.blurb)
                        .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mixSummary(city))
                        .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                    if !open {
                        CounterButton(title: house.cash >= city.openingCost
                                        ? "Open a counter for \(Tally.florins(city.openingCost))"
                                        : "Needs \(Tally.florins(city.openingCost))",
                                      weight: .solid,
                                      enabled: house.cash >= city.openingCost) {
                            house.openCounter(in: city)
                        }
                    }
                }
            }
            CounterCard(tint: Ink.parchmentDim) {
                Text("Every counter you open brings its own mix of trades to the door. That is the surest way to keep the book from leaning on one kind of business.")
                    .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func mixSummary(_ city: CityID) -> String {
        let mix = city.sectorMix
        let ranked = HouseSector.allCases.sorted { (mix[$0] ?? 0) > (mix[$1] ?? 0) }
        return "Mostly " + ranked.prefix(2).map { $0.label.lowercased() }.joined(separator: " and ")
    }
}
