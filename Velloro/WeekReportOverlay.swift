import SwiftUI

struct WeekReportOverlay: View {
    @ObservedObject var house: HouseLedger
    let dismiss: () -> Void

    private var rulings: [LoanRecord] { house.pendingRulings }

    private var weekNet: Int {
        house.weekNotes.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            Ink.parchment.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                CounterHeader(title: "The week is closed",
                              subtitle: "\(Tally.ordinalWeek(house.week)) · \(house.seasonLabel), year \(house.year)")

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        tallyCard
                        if !rulings.isEmpty { rulingSection }
                        notesSection
                        CounterButton(title: rulings.isEmpty
                                        ? "Return to the counter"
                                        : "Rule on \(rulings.count) failed loan\(rulings.count == 1 ? "" : "s") first",
                                      weight: .solid,
                                      enabled: rulings.isEmpty) { dismiss() }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .frame(maxWidth: Measure.column)
                    .frame(maxWidth: .infinity)
                }
                .background(Ink.parchment)
            }
        }
    }

    private var tallyCard: some View {
        CounterCard {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Coin in the chest").font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(Tally.florins(house.cash)).font(Quill.numeral(22)).foregroundColor(Ink.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("The week's account").font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(Tally.signedCoin(weekNet))
                        .font(Quill.numeral(18))
                        .foregroundColor(weekNet >= 0 ? Ink.good : Ink.bad)
                }
            }
            Rectangle().fill(Ink.rule).frame(height: 1)
            CounterStatRow(label: "Claims still open", value: "\(house.liveLoans.count)")
            CounterStatRow(label: "Standing", value: "\(Int(house.standing.rounded()))")
        }
    }

    // MARK: - Rulings — the only place the seizure decision is made

    private var rulingSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "The house must rule", note: "\(rulings.count)")
            ForEach(rulings) { loan in
                RulingCard(loan: loan,
                           staff: house.staff,
                           seize: { house.rule(on: loan.id, choice: .seized) },
                           compose: { house.rule(on: loan.id, choice: .composed) })
            }
        }
    }

    private var notesSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "What passed")
            if house.weekNotes.isEmpty {
                CounterCard {
                    Text("A quiet week. Nothing came due and nothing was said.")
                        .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                }
            } else {
                ForEach(house.weekNotes) { note in
                    CounterCard {
                        HStack(alignment: .top, spacing: 9) {
                            Glyph(shape: glyph(for: note.kind), size: 14, color: colour(for: note.kind))
                                .padding(.top, 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.headline)
                                    .font(Quill.heading(14)).foregroundColor(Ink.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !note.detail.isEmpty {
                                    Text(note.detail)
                                        .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 6)
                            if note.amount != 0 {
                                Text(Tally.signedCoin(note.amount))
                                    .font(Quill.smallNumeral(13))
                                    .foregroundColor(note.amount >= 0 ? Ink.good : Ink.bad)
                            }
                        }
                    }
                }
            }
        }
    }

    private func glyph(for kind: WeekNoteKind) -> AnyShapeWrapper {
        switch kind {
        case .repaid: return AnyShapeWrapper(CoinGlyph())
        case .late, .partial: return AnyShapeWrapper(AlertGlyph())
        case .failed: return AnyShapeWrapper(AlertGlyph())
        case .event: return AnyShapeWrapper(CityGlyph())
        case .upkeep: return AnyShapeWrapper(HouseGlyph())
        case .ruling: return AnyShapeWrapper(SealGlyph())
        default: return AnyShapeWrapper(SealGlyph())
        }
    }

    private func colour(for kind: WeekNoteKind) -> Color {
        switch kind {
        case .repaid: return Ink.good
        case .late, .partial: return Ink.caution
        case .failed: return Ink.bad
        case .event: return Ink.burgundy
        case .upkeep: return Ink.textFaint
        default: return Ink.gold
        }
    }
}

/// A failed loan awaiting the house's decision. The two actions are siblings —
/// neither is nested inside the other's label.
struct RulingCard: View {
    let loan: LoanRecord
    let staff: HouseStaff
    let seize: () -> Void
    let compose: () -> Void

    private var seizeReturn: Int { CounterEngine.recovery(for: loan, choice: .seized, staff: staff).cash }
    private var composeReturn: Int { CounterEngine.recovery(for: loan, choice: .composed, staff: staff).cash }

    var body: some View {
        CounterCard(tint: Color(red: 0.965, green: 0.910, blue: 0.855), edge: Ink.bad.opacity(0.5)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.borrower).font(Quill.heading(16)).foregroundColor(Ink.text)
                    Text("\(loan.trade.label) · lent \(Tally.florins(loan.principal)) · owed \(Tally.florins(loan.amountDue))")
                        .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if loan.pledges.isEmpty {
                Text("Nothing was pledged. There is little to take and only the courts to pursue.")
                    .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(loan.pledges) { pledge in
                    HStack {
                        Text(pledge.kind.label).font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                        Spacer()
                        Text("said \(pledge.statedValue) fl · \(pledge.kind.liquidityLabel.lowercased())")
                            .font(Quill.label(10)).foregroundColor(Ink.textFaint)
                    }
                }
            }
            Rectangle().fill(Ink.rule).frame(height: 1)
            HStack(spacing: 9) {
                VStack(spacing: 6) {
                    Text("Seize the pledges")
                        .font(Quill.label(11)).foregroundColor(Ink.textSoft)
                    Text("about \(Tally.florins(seizeReturn))")
                        .font(Quill.smallNumeral(13)).foregroundColor(Ink.text)
                    Text("standing -\(String(format: "%.1f", staff.seizureStandingCost))")
                        .font(Quill.label(10)).foregroundColor(Ink.bad)
                    CounterButton(title: "Seize", weight: .danger, action: seize)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text("Compose terms")
                        .font(Quill.label(11)).foregroundColor(Ink.textSoft)
                    Text("about \(Tally.florins(composeReturn))")
                        .font(Quill.smallNumeral(13)).foregroundColor(Ink.text)
                    Text("standing +1.8")
                        .font(Quill.label(10)).foregroundColor(Ink.good)
                    CounterButton(title: "Compose", weight: .outline, action: compose)
                }
                .frame(maxWidth: .infinity)
            }
            Text("Pressing a claim raises more coin when the pledges are good. Composing raises more when they are not, and the city remembers either way.")
                .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
