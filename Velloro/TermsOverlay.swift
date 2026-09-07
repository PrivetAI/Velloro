import SwiftUI

struct TermsOverlay: View {
    @ObservedObject var house: HouseLedger
    let applicant: LoanApplicant
    let dismiss: () -> Void

    @State private var terms: OfferTerms
    @State private var verdict: String? = nil
    @State private var verdictGood = true

    init(house: HouseLedger, applicant: LoanApplicant, dismiss: @escaping () -> Void) {
        self.house = house
        self.applicant = applicant
        self.dismiss = dismiss
        var opening = OfferTerms()
        opening.instrument = .loan
        opening.rate = 0.20
        opening.termWeeks = min(max(applicant.askedTerm, CounterEngine.termBounds.lowerBound),
                                CounterEngine.termBounds.upperBound)
        opening.requiredPledgeIDs = Set(applicant.pledges.map { $0.id })
        _terms = State(initialValue: opening)
    }

    // MARK: - Derived

    private var outlay: Int { house.outlay(for: applicant, terms: terms) }

    private var faceValue: Int {
        switch terms.instrument {
        case .loan:
            return applicant.amount + Int((Double(applicant.amount) * terms.rate * Double(terms.termWeeks) / 13.0).rounded())
        case .bill:
            return applicant.amount
        case .commenda:
            return applicant.amount
        }
    }

    private var chosenPledges: [Pledge] { terms.requiredPledges(from: applicant) }

    private var coverage: Double {
        guard applicant.amount > 0 else { return 0 }
        return Double(chosenPledges.reduce(0) { $0 + $1.statedValue }) / Double(applicant.amount)
    }

    private var forcedSaleEstimate: Int {
        Int(chosenPledges.reduce(0.0) {
            $0 + Double($1.statedValue) * $1.kind.liquidity * house.staff.seizureEfficiency
        }.rounded())
    }

    private var acceptance: Double {
        CounterEngine.acceptanceOdds(applicant: applicant, terms: terms)
    }

    private var billAvailable: Bool {
        house.unlockedInstruments.contains(.bill) && applicant.amount <= house.billCeiling
    }

    private var affordable: Bool { house.cash >= outlay }

    var body: some View {
        ZStack {
            Ink.parchment.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                CounterHeader(title: "Set the Terms",
                              subtitle: "\(applicant.name), \(applicant.trade.label)",
                              trailing: AnyView(closeButton))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        applicantCard
                        instrumentCard
                        rateCard
                        termCard
                        if terms.instrument == .loan { pledgeCard }
                        reckoningCard
                        actionCard
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .frame(maxWidth: Measure.column)
                    .frame(maxWidth: .infinity)
                }
                .background(Ink.parchment)
            }

            if let verdict = verdict {
                verdictPane(verdict)
            }
        }
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            HStack(spacing: 5) {
                StrokedGlyph(shape: CrossGlyph(), size: 12, color: Ink.burgundy, lineWidth: 2)
                Text("Back").font(Quill.label(12)).foregroundColor(Ink.burgundy)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(Ink.card).overlay(Capsule().stroke(Ink.cardEdge, lineWidth: 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }

    // MARK: - Cards

    private var applicantCard: some View {
        CounterCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Asks for")
                        .font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(Tally.florins(applicant.amount))
                        .font(Quill.numeral(22)).foregroundColor(Ink.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Over").font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(Tally.weeks(applicant.askedTerm))
                        .font(Quill.numeral(16)).foregroundColor(Ink.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Standing").font(Quill.label(11)).foregroundColor(Ink.textFaint)
                    Text(applicant.standing.label)
                        .font(Quill.heading(14)).foregroundColor(Ink.burgundy)
                }
            }
            Rectangle().fill(Ink.rule).frame(height: 1)
            Text("Wants it \(applicant.purpose). Of \(applicant.city.label).")
                .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            CounterSectionTitle(text: "What is known at the counter")
            FlowTags(items: applicant.visibleCues.map { $0.label })
            if applicant.hiddenCueCount > 0 {
                Text("There are \(applicant.hiddenCueCount) further matter\(applicant.hiddenCueCount == 1 ? "" : "s") your clerks could not look into. A better clerk sees more.")
                    .font(Quill.body(11.5)).foregroundColor(Ink.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var instrumentCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Instrument")
            HStack(spacing: 8) {
                instrumentButton(.loan, enabled: true)
                instrumentButton(.bill, enabled: billAvailable)
                instrumentButton(.commenda, enabled: house.unlockedInstruments.contains(.commenda))
            }
            Text(terms.instrument.blurb)
                .font(Quill.body(12)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            if !billAvailable && house.unlockedInstruments.contains(.bill) {
                Text("A bill may not exceed \(Tally.florins(house.billCeiling)) with your present correspondent.")
                    .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
            }
            if let hint = house.nextInstrumentHint {
                Text(hint).font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func instrumentButton(_ kind: InstrumentKind, enabled: Bool) -> some View {
        let chosen = terms.instrument == kind
        return Button(action: {
            // Re-tapping the instrument already chosen must not wipe tuned terms.
            guard enabled, terms.instrument != kind else { return }
            terms.instrument = kind
            switch kind {
            case .loan:
                terms.rate = min(max(0.20, CounterEngine.rateBounds.lowerBound), CounterEngine.rateBounds.upperBound)
                terms.termWeeks = min(max(applicant.askedTerm, 4), 26)
                terms.requiredPledgeIDs = Set(applicant.pledges.map { $0.id })
            case .bill:
                terms.rate = 0.04
                terms.termWeeks = min(max(applicant.askedTerm, 4), 8)
                terms.requiredPledgeIDs = []
            case .commenda:
                terms.rate = 0.50
                terms.termWeeks = min(max(applicant.askedTerm, 6), 26)
                terms.requiredPledgeIDs = []
            }
        }) {
            Text(kind.shortLabel)
                .font(Quill.label(12))
                .foregroundColor(enabled ? (chosen ? Ink.goldPale : Ink.burgundy) : Ink.textFaint)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(chosen ? Ink.burgundy : Ink.card)
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Ink.cardEdge, lineWidth: 1))
                )
                .opacity(enabled ? 1 : 0.5)
                .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }

    private var rateBounds: ClosedRange<Double> {
        switch terms.instrument {
        case .loan: return CounterEngine.rateBounds
        case .bill: return CounterEngine.discountBounds
        case .commenda: return CounterEngine.shareBounds
        }
    }

    private var rateStep: Double {
        switch terms.instrument {
        case .loan: return 0.005
        case .bill: return 0.005
        case .commenda: return 0.010
        }
    }

    private var rateTitle: String {
        switch terms.instrument {
        case .loan: return "Rate — per hundred, the quarter"
        case .bill: return "Discount — what you hold back"
        case .commenda: return "Your share of the venture"
        }
    }

    private var rateCard: some View {
        CounterCard {
            CounterSectionTitle(text: rateTitle)
            HStack(spacing: 10) {
                nudgeButton(minus: true) {
                    terms.rate = max(rateBounds.lowerBound, terms.rate - rateStep)
                }
                Text(Tally.rate(terms.rate))
                    .font(Quill.numeral(24)).foregroundColor(Ink.burgundy)
                    .frame(minWidth: 92)
                nudgeButton(minus: false) {
                    terms.rate = min(rateBounds.upperBound, terms.rate + rateStep)
                }
                Spacer(minLength: 0)
                if terms.instrument == .loan {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Interest at term").font(Quill.label(10)).foregroundColor(Ink.textFaint)
                        Text(Tally.florins(faceValue - applicant.amount))
                            .font(Quill.smallNumeral(15)).foregroundColor(Ink.text)
                    }
                }
            }
            SlideTrack(value: $terms.rate, bounds: rateBounds, step: rateStep)
            Text(rateFootnote)
                .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rateFootnote: String {
        switch terms.instrument {
        case .loan:
            return "A hard rate prices the risk, and it also presses the borrower harder. Ask too much and the custom goes elsewhere."
        case .bill:
            return "You pay \(Tally.florins(outlay)) now and are paid \(Tally.florins(applicant.amount)) at maturity. The whole gain is the discount."
        case .commenda:
            return "You take \(Tally.rate(terms.rate)) of any profit. If the venture loses, the loss is yours alone — that is the bargain."
        }
    }

    private var termCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Term")
            HStack(spacing: 10) {
                nudgeButton(minus: true) {
                    terms.termWeeks = max(termLimits.lowerBound, terms.termWeeks - 1)
                }
                Text("\(terms.termWeeks)")
                    .font(Quill.numeral(24)).foregroundColor(Ink.burgundy)
                    .frame(minWidth: 52)
                nudgeButton(minus: false) {
                    terms.termWeeks = min(termLimits.upperBound, terms.termWeeks + 1)
                }
                Text("weeks").font(Quill.body(13)).foregroundColor(Ink.textSoft)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Asked for").font(Quill.label(10)).foregroundColor(Ink.textFaint)
                    Text(Tally.weeks(applicant.askedTerm))
                        .font(Quill.smallNumeral(14)).foregroundColor(Ink.text)
                }
            }
            SlideTrack(value: Binding(get: { Double(terms.termWeeks) },
                                      set: { terms.termWeeks = Int($0.rounded()) }),
                       bounds: Double(termLimits.lowerBound)...Double(termLimits.upperBound),
                       step: 1)
            Text("A long term earns more interest and gives misfortune more time to arrive. A short term returns your coin to the chest sooner.")
                .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var termLimits: ClosedRange<Int> {
        terms.instrument == .bill ? CounterEngine.billTermBounds : CounterEngine.termBounds
    }

    private var pledgeCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Pledges you require",
                                note: chosenPledges.isEmpty ? "none" : Tally.coin(chosenPledges.reduce(0) { $0 + $1.statedValue }))
            if applicant.pledges.isEmpty {
                Text("Nothing is offered but a word. If the debt fails, only the courts remain, and they return little.")
                    .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(applicant.pledges) { pledge in
                    PledgeRow(pledge: pledge,
                              chosen: terms.requiredPledgeIDs.contains(pledge.id),
                              appraisalNote: appraisalNote,
                              toggle: {
                                  if terms.requiredPledgeIDs.contains(pledge.id) {
                                      terms.requiredPledgeIDs.remove(pledge.id)
                                  } else {
                                      terms.requiredPledgeIDs.insert(pledge.id)
                                  }
                              })
                }
                Rectangle().fill(Ink.rule).frame(height: 1)
                CounterStatRow(label: "Cover against the sum",
                               value: Tally.percent(coverage),
                               valueColor: coverage >= 0.8 ? Ink.good : (coverage >= 0.4 ? Ink.caution : Ink.bad))
                CounterStatRow(label: "Likely raised at forced sale",
                               value: Tally.florins(forcedSaleEstimate))
                Text("Asking for the tools of a trade costs far more goodwill than asking for plate.")
                    .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appraisalNote: String {
        switch house.staff.assayerTier {
        case 0: return "on the borrower's own word"
        case 1: return "checked by your assayer"
        default: return "weighed by your master assayer"
        }
    }

    private var reckoningCard: some View {
        CounterCard(tint: Ink.parchmentDim) {
            CounterSectionTitle(text: "The reckoning")
            CounterStatRow(label: "Coin leaving the chest", value: Tally.florins(outlay),
                           valueColor: affordable ? Ink.text : Ink.bad, emphasis: true)
            if terms.instrument == .commenda {
                CounterStatRow(label: "Returned at term", value: "Whatever the venture earns")
            } else {
                CounterStatRow(label: "Due at term", value: Tally.florins(faceValue))
                CounterStatRow(label: "Your gain if it is paid",
                               value: Tally.signedCoin(faceValue - outlay),
                               valueColor: Ink.good)
            }
            CounterStatRow(label: "Chest after the offer",
                           value: Tally.florins(max(0, house.cash - outlay)))
            Rectangle().fill(Ink.rule).frame(height: 1)
            HStack(alignment: .center, spacing: 8) {
                Glyph(shape: StandingGlyph(), size: 15, color: Ink.gold)
                Text(CounterEngine.acceptanceReading(acceptance))
                    .font(Quill.heading(14))
                    .foregroundColor(acceptance >= 0.55 ? Ink.good : (acceptance >= 0.3 ? Ink.caution : Ink.bad))
                Spacer(minLength: 0)
            }
            Text("Your terms are being weighed against what could be had elsewhere. Nobody tells you what can truly be borne.")
                .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionCard: some View {
        VStack(spacing: 9) {
            CounterButton(title: affordable ? "Offer these terms" : "The chest cannot cover it",
                          weight: .solid, enabled: affordable) {
                guard verdict == nil else { return }
                let result = house.offer(terms, to: applicant)
                switch result {
                case .accepted:
                    verdictGood = true
                    verdict = "\(applicant.name) takes the terms and signs the book. \(Tally.florins(outlay)) leaves the chest."
                case .walked:
                    verdictGood = false
                    verdict = "\(applicant.name) will not have it at that price, bows, and goes looking elsewhere."
                case .shortOfCoin:
                    verdictGood = false
                    verdict = "There is not enough coin in the chest to make this loan."
                }
            }
            CounterButton(title: "Decline the request", weight: .outline) {
                guard verdict == nil else { return }
                house.decline(applicant)
                verdictGood = false
                verdict = "You send \(applicant.name) away without an offer. Word of it travels, a little."
            }
        }
    }

    private func verdictPane(_ text: String) -> some View {
        ZStack {
            Color.black.opacity(0.35).edgesIgnoringSafeArea(.all)
            CounterCard {
                HStack(spacing: 10) {
                    Glyph(shape: verdictGood ? AnyShapeWrapper(SealGlyph()) : AnyShapeWrapper(AlertGlyph()),
                          size: 20, color: verdictGood ? Ink.good : Ink.caution)
                    Text(verdictGood ? "Agreed" : "Not agreed")
                        .font(Quill.heading(17)).foregroundColor(Ink.text)
                }
                Text(text)
                    .font(Quill.body(14)).foregroundColor(Ink.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                CounterButton(title: "Back to the counter", weight: .solid) { dismiss() }
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: Measure.column)
        }
    }

    private func nudgeButton(minus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if minus {
                    Glyph(shape: MinusGlyph(), size: 17, color: Ink.goldPale)
                } else {
                    Glyph(shape: PlusGlyph(), size: 17, color: Ink.goldPale)
                }
            }
            .frame(width: 40, height: 36)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.burgundy))
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }
}

/// Type-erasing wrapper so one call site can pick between two Shapes.
struct AnyShapeWrapper: Shape {
    private let builder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { builder = { rect in shape.path(in: rect) } }
    func path(in rect: CGRect) -> Path { builder(rect) }
}

// MARK: - Custom controls (nothing here is a system control)

struct SlideTrack: View {
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        GeometryReader { geo in
            let width = max(24, geo.size.width)
            let span = max(0.0001, bounds.upperBound - bounds.lowerBound)
            let fraction = CGFloat(min(1, max(0, (value - bounds.lowerBound) / span)))
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.parchmentDim)
                    .frame(height: 8)
                    .frame(maxHeight: .infinity, alignment: .center)
                Capsule().fill(Ink.burgundy)
                    .frame(width: fraction * width, height: 8)
                    .frame(maxHeight: .infinity, alignment: .center)
                Circle()
                    .fill(Ink.goldBright)
                    .overlay(Circle().stroke(Ink.burgundyDeep, lineWidth: 1.5))
                    .frame(width: 22, height: 22)
                    .offset(x: max(0, min(width - 22, fraction * width - 11)))
            }
            .frame(width: width, height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clamped = min(max(0, drag.location.x), width)
                        let raw = bounds.lowerBound + Double(clamped / width) * span
                        let snapped = (raw / step).rounded() * step
                        value = min(max(snapped, bounds.lowerBound), bounds.upperBound)
                    }
            )
        }
        .frame(height: 32)
    }
}

struct PledgeRow: View {
    let pledge: Pledge
    let chosen: Bool
    let appraisalNote: String
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .center, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(chosen ? Ink.burgundy : Ink.card)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Ink.burgundyDeep.opacity(0.6), lineWidth: 1.3))
                        .frame(width: 22, height: 22)
                    if chosen {
                        StrokedGlyph(shape: TickGlyph(), size: 14, color: Ink.goldPale, lineWidth: 2.2)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(pledge.kind.label)
                        .font(Quill.heading(14)).foregroundColor(Ink.text)
                    Text("\(pledge.kind.liquidityLabel) · \(appraisalNote)")
                        .font(Quill.label(10.5)).foregroundColor(Ink.textFaint)
                }
                Spacer(minLength: 6)
                Text(Tally.florins(pledge.statedValue))
                    .font(Quill.smallNumeral(14)).foregroundColor(Ink.burgundy)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }
}
