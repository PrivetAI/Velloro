import SwiftUI

struct ContentView: View {
    @StateObject private var house = HouseLedger()

    @State private var tab: Int = 0
    @State private var reviewing: LoanApplicant? = nil
    @State private var showGuide = false
    @State private var showReport = false
    /// The ruin notice can be set aside so the ledger stays readable after a collapse.
    @State private var ruinAcknowledged = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Ink.parchment.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Group {
                        switch tab {
                        case 0: CounterView(house: house, reviewing: $reviewing, showReport: $showReport)
                        case 1: LedgerView(house: house)
                        case 2: HouseView(house: house)
                        case 3: CityView(house: house)
                        default: MoreView(house: house, showGuide: $showGuide)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CounterTabBar(selected: $tab, alerts: house.queue.count)
                }

                // One overlay at a time, each with its own opaque top band.
                if let applicant = reviewing {
                    TermsOverlay(house: house,
                                 applicant: applicant,
                                 dismiss: { withAnimation(.easeInOut(duration: 0.18)) { reviewing = nil } })
                        .transition(.opacity)
                        .zIndex(2)
                } else if showReport {
                    WeekReportOverlay(house: house,
                                      dismiss: { withAnimation(.easeInOut(duration: 0.18)) { showReport = false } })
                        .transition(.opacity)
                        .zIndex(3)
                } else if showGuide {
                    GuideOverlay(dismiss: {
                        house.markGuideSeen()
                        withAnimation(.easeInOut(duration: 0.18)) { showGuide = false }
                    })
                    .transition(.opacity)
                    .zIndex(4)
                } else if house.isRuined && !ruinAcknowledged {
                    RuinOverlay(house: house,
                                readOn: { withAnimation(.easeInOut(duration: 0.18)) { ruinAcknowledged = true } })
                        .transition(.opacity)
                        .zIndex(5)
                }
            }
            .environment(\.counterSize, geo.size)
        }
        .onChange(of: house.isRuined) { ruined in
            if !ruined { ruinAcknowledged = false }
        }
        .onChange(of: tab) { index in
            // Returning to the counter brings the ruin notice — and the way to begin
            // again — back, so setting it aside can never strand the player.
            if index == 0 { ruinAcknowledged = false }
        }
        .onAppear {
            if !house.hasSeenGuide { showGuide = true }
            // A campaign killed mid-ruling comes back to the same decision.
            if !house.pendingRulings.isEmpty { showReport = true }
        }
    }
}

// MARK: - Tab bar (hand-built; SwiftUI's TabView cannot render Shape icons)

struct CounterTabBar: View {
    @Binding var selected: Int
    var alerts: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, label: "Counter", badge: alerts) {
                AnyView(Glyph(shape: BalanceGlyph(), size: 23, color: tint(0)))
            }
            tabButton(index: 1, label: "Ledger", badge: 0) {
                AnyView(Glyph(shape: LedgerGlyph(), size: 23, color: tint(1)))
            }
            tabButton(index: 2, label: "House", badge: 0) {
                AnyView(Glyph(shape: HouseGlyph(), size: 23, color: tint(2)))
            }
            tabButton(index: 3, label: "City", badge: 0) {
                AnyView(Glyph(shape: CityGlyph(), size: 23, color: tint(3)))
            }
            tabButton(index: 4, label: "More", badge: 0) {
                AnyView(Glyph(shape: QuillGlyph(), size: 23, color: tint(4)))
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(
            Ink.burgundyDeep
                .overlay(Rectangle().fill(Ink.gold.opacity(0.55)).frame(height: 1.5), alignment: .top)
                .edgesIgnoringSafeArea([.bottom, .horizontal])
        )
    }

    private func tint(_ index: Int) -> Color {
        selected == index ? Ink.goldBright : Ink.goldPale.opacity(0.45)
    }

    private func tabButton(index: Int, label: String, badge: Int,
                           icon: @escaping () -> AnyView) -> some View {
        Button(action: { selected = index }) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    icon()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(Quill.smallNumeral(9))
                            .foregroundColor(Ink.burgundyDeep)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Ink.goldBright))
                            .offset(x: 9, y: -5)
                    }
                }
                .frame(height: 26)
                Text(label)
                    .font(Quill.label(10))
                    .foregroundColor(tint(index))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(FlatPressStyle())
    }
}
