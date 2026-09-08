import SwiftUI

struct LedgerView: View {
    @ObservedObject var house: HouseLedger

    @State private var mode: Int = 0            // 0 outstanding · 1 settled · 2 signals
    @State private var sectorFilter: HouseSector? = nil
    @State private var outcomeFilter: LoanStatus? = nil
    @State private var expanded: Set<UUID> = []

    private let rowCap = 120

    var body: some View {
        CounterPage(title: "The Ledger",
                    subtitle: "Every bargain this house has struck") {
            summaryCard
            modeSelector
            switch mode {
            case 0: outstandingList
            case 1: settledList
            default: signalStudy
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        CounterCard {
            HStack(spacing: 0) {
                ledgerStat(title: "Out on loan", value: Tally.coin(house.outstandingPrincipal))
                ledgerStat(title: "Claims live", value: "\(house.liveLoans.count)")
                ledgerStat(title: "Settled", value: "\(house.settledLoans.count)")
            }
            Rectangle().fill(Ink.rule).frame(height: 1)
            HStack(spacing: 0) {
                ledgerStat(title: "Interest taken", value: Tally.coin(house.save.lifetimeInterest),
                           color: Ink.good)
                ledgerStat(title: "Coin lost", value: Tally.coin(house.save.lifetimeLosses),
                           color: Ink.bad)
                ledgerStat(title: "Went bad", value: Tally.percent(house.overallFailureRate),
                           color: house.overallFailureRate > 0.25 ? Ink.bad : Ink.text)
            }
            if house.concentrationIndex > 0 {
                Rectangle().fill(Ink.rule).frame(height: 1)
                concentrationLine
            }
        }
    }

    private var concentrationLine: some View {
        let index = house.concentrationIndex
        let penalty = house.concentrationPenalty
        let severe = penalty > 0.55
        let mild = penalty > 0.05
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Spread of the book")
                    .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                Spacer()
                Text(severe ? "Dangerously narrow" : (mild ? "Narrow" : "Well spread"))
                    .font(Quill.label(11))
                    .foregroundColor(severe ? Ink.bad : (mild ? Ink.caution : Ink.good))
            }
            CounterBar(fraction: min(1, (index - 0.2) / 0.8),
                       fill: severe ? Ink.bad : (mild ? Ink.caution : Ink.good))
            if mild {
                Text("Too much of the house's coin sits in one kind of trade. One bad season there strikes the whole book at once.")
                    .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ledgerStat(title: String, value: String, color: Color = Ink.text) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Quill.smallNumeral(16)).foregroundColor(color)
            Text(title).font(Quill.label(10)).foregroundColor(Ink.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mode

    private var modeSelector: some View {
        HStack(spacing: 8) {
            modeButton(0, "Outstanding")
            modeButton(1, "Settled")
            modeButton(2, "Signals")
        }
    }

    private func modeButton(_ index: Int, _ title: String) -> some View {
        let chosen = mode == index
        return Button(action: { mode = index }) {
            Text(title)
                .font(Quill.label(12))
                .foregroundColor(chosen ? Ink.goldPale : Ink.burgundy)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(chosen ? Ink.burgundy : Ink.card)
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Ink.cardEdge, lineWidth: 1))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }

    // MARK: - Filters

    private var sectorFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                filterChip(title: "All trades", active: sectorFilter == nil) { sectorFilter = nil }
                ForEach(HouseSector.allCases, id: \.self) { sector in
                    filterChip(title: sector.label, active: sectorFilter == sector) {
                        sectorFilter = sectorFilter == sector ? nil : sector
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var outcomeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                filterChip(title: "Any outcome", active: outcomeFilter == nil) { outcomeFilter = nil }
                ForEach([LoanStatus.repaidOnTime, .repaidLate, .repaidPartly, .defaulted], id: \.self) { status in
                    filterChip(title: status.label, active: outcomeFilter == status) {
                        outcomeFilter = outcomeFilter == status ? nil : status
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func filterChip(title: String, active: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(Quill.label(11))
                .foregroundColor(active ? Ink.goldPale : Ink.textSoft)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(active ? Ink.burgundy : Ink.card)
                        .overlay(Capsule().stroke(Ink.cardEdge, lineWidth: 1))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }

    // MARK: - Lists

    private var filteredLive: [LoanRecord] {
        house.liveLoans
            .filter { sectorFilter == nil || $0.sector == sectorFilter }
            .sorted { $0.dueWeek < $1.dueWeek }
    }

    private var filteredSettled: [LoanRecord] {
        house.settledLoans
            .filter { sectorFilter == nil || $0.sector == sectorFilter }
            .filter { outcomeFilter == nil || $0.status == outcomeFilter }
            .sorted { ($0.resolvedWeek ?? 0) > ($1.resolvedWeek ?? 0) }
    }

    private var outstandingList: some View {
        VStack(spacing: 10) {
            sectorFilterRow
            if filteredLive.isEmpty {
                CounterCard {
                    Text("No claims stand open under this filter.")
                        .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                }
            } else {
                CounterSectionTitle(text: "Open claims", note: "\(filteredLive.count)")
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredLive.prefix(rowCap))) { loan in
                        LedgerRow(loan: loan, week: house.week,
                                  expanded: expanded.contains(loan.id)) {
                            toggle(loan.id)
                        }
                    }
                }
                if filteredLive.count > rowCap {
                    Text("Showing the \(rowCap) nearest of \(filteredLive.count).")
                        .font(Quill.label(11)).foregroundColor(Ink.textFaint)
                }
            }
        }
    }

    private var settledList: some View {
        VStack(spacing: 10) {
            sectorFilterRow
            outcomeFilterRow
            if filteredSettled.isEmpty {
                CounterCard {
                    Text("Nothing has settled under this filter yet. Close a few weeks and the record will fill.")
                        .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                CounterSectionTitle(text: "Settled", note: settledNote)
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredSettled.prefix(rowCap))) { loan in
                        LedgerRow(loan: loan, week: house.week,
                                  expanded: expanded.contains(loan.id)) {
                            toggle(loan.id)
                        }
                    }
                }
                if filteredSettled.count > rowCap {
                    Text("Showing the \(rowCap) most recent of \(filteredSettled.count).")
                        .font(Quill.label(11)).foregroundColor(Ink.textFaint)
                }
            }
        }
    }

    private var settledNote: String {
        let list = filteredSettled
        guard !list.isEmpty else { return "0" }
        let bad = list.filter { $0.status == .defaulted || $0.status == .repaidPartly }.count
        let net = list.reduce(0) { $0 + $1.profit }
        return "\(list.count) · \(Tally.percent(Double(bad) / Double(list.count))) bad · \(Tally.signedCoin(net))"
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    // MARK: - Signal study

    private var signalStudy: some View {
        let lines = house.signalStudy()
        let settled = house.settledLoans.count
        return VStack(spacing: 10) {
            CounterCard(tint: Ink.parchmentDim) {
                CounterSectionTitle(text: "Reading the signs")
                Text("Nobody will ever tell you which remarks about an applicant actually matter. This page counts your own settled claims: how often a bargain went bad when a given thing was said of the borrower, against how often it went bad when it was not.")
                    .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Some remarks are worth a great deal. Some are worth nothing at all and only look important. Judge by the difference, and do not trust a line drawn from four or five claims.")
                    .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                CounterStatRow(label: "Claims settled so far", value: "\(settled)")
                CounterStatRow(label: "Went bad overall",
                               value: Tally.percent(house.overallFailureRate))
            }
            if lines.isEmpty {
                CounterCard {
                    Text("The book is empty. Make some loans and let them run their course.")
                        .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(lines) { line in
                        SignalStudyCard(line: line)
                    }
                }
            }
        }
    }
}

// MARK: - Rows

struct LedgerRow: View {
    let loan: LoanRecord
    let week: Int
    let expanded: Bool
    let toggle: () -> Void

    private var statusColor: Color {
        switch loan.status {
        case .outstanding: return Ink.burgundy
        case .repaidOnTime: return Ink.good
        case .repaidLate: return Ink.caution
        case .repaidPartly: return Ink.caution
        case .defaulted: return Ink.bad
        }
    }

    private var rateLabel: String {
        switch loan.instrument {
        case .loan: return "\(Tally.rate(loan.rate)) the quarter"
        case .bill: return "\(Tally.rate(loan.rate)) discount"
        case .commenda: return "\(Tally.rate(loan.rate)) of profit"
        }
    }

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loan.borrower)
                            .font(Quill.heading(15)).foregroundColor(Ink.text)
                        Text("\(loan.trade.label) · \(loan.instrument.shortLabel) · \(rateLabel)")
                            .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Tally.florins(loan.principal))
                            .font(Quill.smallNumeral(15)).foregroundColor(Ink.text)
                        Text(loan.status == .outstanding
                             ? "due in \(max(0, loan.dueWeek - week)) wk"
                             : Tally.signedCoin(loan.profit))
                            .font(Quill.label(10.5))
                            .foregroundColor(loan.status == .outstanding
                                             ? Ink.textFaint
                                             : (loan.profit >= 0 ? Ink.good : Ink.bad))
                    }
                }

                HStack(spacing: 6) {
                    CounterTag(text: loan.status.label,
                               fill: statusColor.opacity(0.14),
                               stroke: statusColor.opacity(0.55),
                               textColor: statusColor)
                    CounterTag(text: loan.sector.label)
                    if let choice = loan.recoveryChoice {
                        CounterTag(text: choice.label)
                    }
                    Spacer(minLength: 0)
                    StrokedGlyph(shape: ChevronGlyph(direction: expanded ? .up : .down),
                                 size: 11, color: Ink.textFaint, lineWidth: 2)
                }

                if expanded { details }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Ink.card)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Ink.cardEdge, lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Ink.rule).frame(height: 1)
            CounterStatRow(label: "Struck in week", value: "\(loan.openedWeek) · \(loan.city.label)")
            CounterStatRow(label: "Term", value: Tally.weeks(loan.termWeeks))
            if loan.instrument != .commenda {
                CounterStatRow(label: "Face value at term", value: Tally.florins(loan.amountDue))
            }
            CounterStatRow(label: "Paid out", value: Tally.florins(loan.cashOut))
            if loan.status.isResolved {
                CounterStatRow(label: "Came back", value: Tally.florins(loan.cashIn),
                               valueColor: loan.cashIn >= loan.cashOut ? Ink.good : Ink.bad)
            }
            CounterStatRow(label: "Standing then", value: loan.standing.label)
            if !loan.pledges.isEmpty {
                CounterSectionTitle(text: "Pledges held")
                ForEach(loan.pledges) { pledge in
                    HStack {
                        Text(pledge.kind.label)
                            .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                        Spacer()
                        Text(loan.status.isResolved
                             ? "said \(Tally.coin(pledge.statedValue)), worth \(Tally.coin(pledge.trueValue))"
                             : "said to be worth \(Tally.coin(pledge.statedValue))")
                            .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                    }
                }
            }
            CounterSectionTitle(text: loan.status.isResolved ? "All that was true of the borrower" : "What you were told")
            FlowTags(items: (loan.status.isResolved ? loan.cuesAll : loan.cuesSeen).map { $0.label })
            if loan.status.isResolved && loan.cuesAll.count > loan.cuesSeen.count {
                Text("\(loan.cuesAll.count - loan.cuesSeen.count) of these came to light only afterwards.")
                    .font(Quill.label(10.5)).foregroundColor(Ink.caution)
            }
        }
    }
}

struct SignalStudyCard: View {
    let line: SignalStudyLine

    private var verdictColor: Color {
        guard line.hasEnough else { return Ink.textFaint }
        if line.lift > 0.12 { return Ink.bad }
        if line.lift < -0.12 { return Ink.good }
        return Ink.textSoft
    }

    private var verdictText: String {
        guard line.hasEnough else { return "Too few to judge" }
        if line.lift > 0.12 { return "Goes bad far more often" }
        if line.lift > 0.04 { return "Goes bad a little more often" }
        if line.lift < -0.12 { return "Goes bad far less often" }
        if line.lift < -0.04 { return "Goes bad a little less often" }
        return "Makes no difference you can see"
    }

    var body: some View {
        CounterCard {
            HStack(alignment: .top) {
                Text(line.cue.label)
                    .font(Quill.heading(14)).foregroundColor(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(line.seen) claims")
                    .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
            }
            VStack(alignment: .leading, spacing: 4) {
                barLine(label: "When it was said", value: line.rateWith, count: line.seen, tint: Ink.burgundy)
                barLine(label: "When not", value: line.rateWithout, count: line.restSeen, tint: Ink.textFaint)
            }
            Text(verdictText)
                .font(Quill.label(11)).foregroundColor(verdictColor)
        }
    }

    private func barLine(label: String, value: Double, count: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Quill.body(11.5)).foregroundColor(Ink.textSoft)
                .frame(width: 108, alignment: .leading)
            CounterBar(fraction: value, fill: tint, height: 7)
            Text(count > 0 ? Tally.percent(value) : "—")
                .font(Quill.smallNumeral(12)).foregroundColor(Ink.text)
                .frame(width: 38, alignment: .trailing)
        }
    }
}
