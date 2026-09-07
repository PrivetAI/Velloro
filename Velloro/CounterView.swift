import SwiftUI

struct CounterView: View {
    @ObservedObject var house: HouseLedger
    @Binding var reviewing: LoanApplicant?
    @Binding var showReport: Bool

    var body: some View {
        CounterPage(title: "The Counter",
                    subtitle: "\(house.houseName) · \(house.seasonLabel), year \(house.year)") {
            treasuryCard
            weekActionCard
            if !house.activeEvents.isEmpty { eventStrip }
            queueSection
        }
    }

    // MARK: - Treasury

    private var treasuryCard: some View {
        CounterCard {
            HStack(alignment: .center, spacing: 12) {
                Glyph(shape: CoinGlyph(), size: 26, color: Ink.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Coin in the chest")
                        .font(Quill.label(11))
                        .foregroundColor(Ink.textFaint)
                    Text(Tally.florins(house.cash))
                        .font(Quill.numeral(24))
                        .foregroundColor(Ink.text)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Out on loan")
                        .font(Quill.label(11))
                        .foregroundColor(Ink.textFaint)
                    Text(Tally.florins(house.outstandingPrincipal))
                        .font(Quill.numeral(18))
                        .foregroundColor(Ink.burgundy)
                }
            }
            Rectangle().fill(Ink.rule).frame(height: 1)
            HStack(spacing: 0) {
                miniStat(title: "Claims", value: "\(house.liveLoans.count)")
                miniStat(title: "Standing", value: "\(Int(house.standing.rounded()))")
                miniStat(title: "Upkeep", value: "\(house.weeklyUpkeep)/wk")
                miniStat(title: "Worth", value: Tally.coin(house.worth))
            }
        }
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Quill.smallNumeral(15))
                .foregroundColor(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(Quill.label(10))
                .foregroundColor(Ink.textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Turning the week

    private var weekActionCard: some View {
        CounterCard(tint: Ink.parchmentDim) {
            HStack(alignment: .firstTextBaseline) {
                Text(Tally.ordinalWeek(house.week))
                    .font(Quill.heading(15))
                    .foregroundColor(Ink.text)
                Spacer()
                Text(house.queue.isEmpty ? "The counter is clear"
                                         : "\(house.queue.count) still waiting")
                    .font(Quill.body(12))
                    .foregroundColor(Ink.textSoft)
            }
            CounterButton(title: "Close the week and turn the ledger", weight: .solid) {
                house.closeTheWeek()
                withAnimation(.easeInOut(duration: 0.18)) { showReport = true }
            }
            Text("Claims come due, wages are paid, and a fresh queue forms at the door.")
                .font(Quill.body(11.5))
                .foregroundColor(Ink.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eventStrip: some View {
        VStack(spacing: 8) {
            ForEach(house.activeEvents) { event in
                CounterCard(tint: event.hazardShift > 0 ? Color(red: 0.965, green: 0.910, blue: 0.855)
                                                        : Color(red: 0.906, green: 0.945, blue: 0.898),
                            edge: event.hazardShift > 0 ? Ink.bad.opacity(0.45) : Ink.good.opacity(0.45)) {
                    HStack(alignment: .top, spacing: 10) {
                        Glyph(shape: AlertGlyph(), size: 16,
                              color: event.hazardShift > 0 ? Ink.bad : Ink.good)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(Quill.heading(14))
                                .foregroundColor(Ink.text)
                            Text(event.detail)
                                .font(Quill.body(12))
                                .foregroundColor(Ink.textSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(event.sectorLabel) · until week \(event.endWeek)")
                                .font(Quill.label(10))
                                .foregroundColor(Ink.textFaint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - The queue

    private var queueSection: some View {
        VStack(spacing: 10) {
            CounterSectionTitle(text: "At the door", note: "\(house.queue.count)")
            if house.queue.isEmpty {
                CounterCard {
                    Text("Nobody waits. Close the week to open the doors again.")
                        .font(Quill.body(14))
                        .foregroundColor(Ink.textSoft)
                }
            } else {
                ForEach(house.queue) { applicant in
                    ApplicantCard(applicant: applicant,
                                  showCity: house.openCities.count > 1,
                                  affordable: house.cash >= applicant.amount) {
                        withAnimation(.easeInOut(duration: 0.18)) { reviewing = applicant }
                    }
                }
            }
        }
    }
}

// MARK: - One applicant

/// The card takes value types only, so it redraws whenever the applicant changes.
/// The whole card is a single Button — nothing is nested inside another button's label.
struct ApplicantCard: View {
    let applicant: LoanApplicant
    let showCity: Bool
    let affordable: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(applicant.name)
                            .font(Quill.heading(16))
                            .foregroundColor(Ink.text)
                        Text(showCity ? "\(applicant.trade.label) · \(applicant.city.label)"
                                      : applicant.trade.label)
                            .font(Quill.body(12))
                            .foregroundColor(Ink.textSoft)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Tally.florins(applicant.amount))
                            .font(Quill.numeral(17))
                            .foregroundColor(affordable ? Ink.burgundy : Ink.textFaint)
                        Text("asks \(Tally.weeks(applicant.askedTerm))")
                            .font(Quill.label(10))
                            .foregroundColor(Ink.textFaint)
                    }
                }

                Text("Wants it \(applicant.purpose).")
                    .font(Quill.body(13))
                    .foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    CounterTag(text: "Standing: \(applicant.standing.label)",
                               fill: Ink.parchmentDim, textColor: Ink.text)
                    CounterTag(text: applicant.pledges.isEmpty
                                ? "No pledge"
                                : "\(applicant.pledges.count) pledge\(applicant.pledges.count == 1 ? "" : "s")")
                    Spacer(minLength: 0)
                }

                // Cues are all styled identically on purpose. Nothing here hints at weight.
                FlowTags(items: applicant.visibleCues.map { $0.label })

                if applicant.hiddenCueCount > 0 {
                    Text("Your clerks could not look into \(applicant.hiddenCueCount) further matter\(applicant.hiddenCueCount == 1 ? "" : "s").")
                        .font(Quill.label(10.5))
                        .foregroundColor(Ink.caution)
                }

                HStack {
                    if !affordable {
                        Text("More than the chest holds")
                            .font(Quill.label(10.5))
                            .foregroundColor(Ink.bad)
                    }
                    Spacer()
                    Text("Set terms")
                        .font(Quill.label(11))
                        .foregroundColor(Ink.burgundy)
                    StrokedGlyph(shape: ChevronGlyph(direction: .right), size: 11,
                                 color: Ink.burgundy, lineWidth: 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Ink.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Ink.cardEdge, lineWidth: 1.2)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }
}

/// Wrapping row of tags. Built by hand because iOS 15 has no flow layout.
struct FlowTags: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                HStack(spacing: 6) {
                    Circle().fill(Ink.gold.opacity(0.8)).frame(width: 5, height: 5)
                    Text(entry.element)
                        .font(Quill.body(12.5))
                        .foregroundColor(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
