import SwiftUI

struct CityView: View {
    @ObservedObject var house: HouseLedger

    var body: some View {
        CounterPage(title: "The City",
                    subtitle: "\(house.seasonLabel), year \(house.year) · \(Tally.ordinalWeek(house.week))") {
            newsSection
            exposureCard
            tradeConditionsCard
            faceSection
        }
    }

    // MARK: - News

    private var newsSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "Word about the city")
            if house.activeEvents.isEmpty {
                CounterCard {
                    Text("Nothing unusual is spoken of. Trade goes on as it has.")
                        .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                }
            } else {
                ForEach(house.activeEvents) { event in
                    CounterCard(tint: event.hazardShift > 0 ? Color(red: 0.965, green: 0.910, blue: 0.855)
                                                            : Color(red: 0.906, green: 0.945, blue: 0.898),
                                edge: event.hazardShift > 0 ? Ink.bad.opacity(0.45) : Ink.good.opacity(0.45)) {
                        HStack(alignment: .top, spacing: 10) {
                            Glyph(shape: AlertGlyph(), size: 17,
                                  color: event.hazardShift > 0 ? Ink.bad : Ink.good)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(Quill.heading(15)).foregroundColor(Ink.text)
                                Text(event.detail)
                                    .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 6) {
                                    CounterTag(text: event.sectorLabel)
                                    CounterTag(text: "\(max(0, event.endWeek - house.week)) wk yet")
                                    if event.volumeShift != 0 {
                                        CounterTag(text: event.volumeShift > 0 ? "More come" : "Fewer come")
                                    }
                                    Spacer(minLength: 0)
                                }
                                .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Exposure

    private var exposureCard: some View {
        let total = max(1, house.outstandingPrincipal)
        return CounterCard {
            CounterSectionTitle(text: "Where the house's coin sits",
                                note: Tally.florins(house.outstandingPrincipal))
            if house.outstandingPrincipal == 0 {
                Text("Nothing is out on loan. Every florin is in the chest.")
                    .font(Quill.body(13.5)).foregroundColor(Ink.textSoft)
            } else {
                ForEach(HouseSector.allCases, id: \.self) { sector in
                    let amount = house.exposure(by: sector)
                    let share = Double(amount) / Double(total)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(sector.label).font(Quill.body(13)).foregroundColor(Ink.text)
                            if isSectorStruck(sector) {
                                CounterTag(text: "under strain",
                                           fill: Ink.bad.opacity(0.15),
                                           stroke: Ink.bad.opacity(0.5),
                                           textColor: Ink.bad)
                            }
                            Spacer()
                            Text("\(Tally.percent(share)) · \(Tally.coin(amount))")
                                .font(Quill.smallNumeral(12)).foregroundColor(Ink.textSoft)
                        }
                        CounterBar(fraction: share,
                                   fill: share > 0.45 ? Ink.bad : (share > 0.30 ? Ink.caution : Ink.burgundy),
                                   height: 7)
                    }
                }
                Rectangle().fill(Ink.rule).frame(height: 1)
                Text(concentrationVerdict)
                    .font(Quill.body(12.5))
                    .foregroundColor(house.concentrationPenalty > 0.35 ? Ink.bad : Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func isSectorStruck(_ sector: HouseSector) -> Bool {
        house.activeEvents.contains { $0.hazardShift > 0 && $0.affects(sector) }
    }

    private var concentrationVerdict: String {
        let penalty = house.concentrationPenalty
        if penalty <= 0.05 {
            return "The book is spread across the trades. A bad season in any one of them costs the house a little, not a great deal."
        }
        if penalty <= 0.35 {
            return "The book leans on one or two kinds of business. Watch the news for those trades."
        }
        if penalty <= 0.8 {
            return "Too much of the house sits in one trade. Every claim on the book is now more likely to fail than its own merits warrant."
        }
        return "The house is staked almost entirely on one trade. If that trade turns, the book turns with it, all at once."
    }

    // MARK: - Trades

    private var tradeConditionsCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Trades at the door")
            Text("Each counter draws a different crowd. What arrives depends on where your houses stand.")
                .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(house.openCities, id: \.self) { city in
                HStack(alignment: .top, spacing: 8) {
                    Glyph(shape: CityGlyph(), size: 15, color: Ink.burgundy).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.label).font(Quill.heading(14)).foregroundColor(Ink.text)
                        Text(city.blurb)
                            .font(Quill.body(12)).foregroundColor(Ink.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Faces

    private var faceSection: some View {
        let honoured = house.save.alumni.filter { $0.honoured }
        let failed = house.save.alumni.filter { !$0.honoured }
        return CounterCard {
            CounterSectionTitle(text: "Faces the house remembers")
            CounterStatRow(label: "Borrowers who honoured their bond", value: "\(honoured.count)",
                           valueColor: Ink.good)
            CounterStatRow(label: "Borrowers who did not", value: "\(failed.count)",
                           valueColor: Ink.bad)
            Text("Old borrowers come back to the counter. Your ledger is the only record of how they behaved last time, and the clerks will always say so.")
                .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
