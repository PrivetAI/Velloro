import SwiftUI

struct MoreView: View {
    @ObservedObject var house: HouseLedger
    @Binding var showGuide: Bool

    @State private var draftName: String = ""
    @State private var confirmingReset = false
    @State private var showPrivacy = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        CounterPage(title: "The Papers",
                    subtitle: "House business and settings") {
            nameCard
            guideCard
            recordCard
            privacyCard
            resetCard
            aboutCard
        }
        // The only sheet anywhere in the app. iOS 15 honours just one per view.
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet(dismiss: { showPrivacy = false })
        }
        .onAppear { draftName = house.houseName }
    }

    // MARK: - Name

    private var nameCard: some View {
        CounterCard {
            CounterSectionTitle(text: "The name over the door")
            // A single text field, focused explicitly so a tap anywhere on the row lands.
            HStack(spacing: 8) {
                TextField("", text: $draftName)
                    .font(Quill.body(15))
                    .foregroundColor(Ink.text)
                    .accentColor(Ink.burgundy)
                    .disableAutocorrection(true)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { commitName() }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Ink.parchment)
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(nameFocused ? Ink.burgundy : Ink.cardEdge, lineWidth: 1.2))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { nameFocused = true }
                if nameFocused {
                    Button(action: commitName) {
                        Text("Done")
                            .font(Quill.label(12)).foregroundColor(Ink.goldPale)
                            .padding(.horizontal, 13).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.burgundy))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FlatPressStyle())
                }
            }
            Text("Written at the head of every page of the ledger.")
                .font(Quill.body(11.5)).foregroundColor(Ink.textFaint)
        }
    }

    private func commitName() {
        house.rename(draftName)
        draftName = house.houseName
        nameFocused = false
    }

    // MARK: - Guide

    private var guideCard: some View {
        CounterCard {
            CounterSectionTitle(text: "How the house works")
            Text("The rules of pricing, pledges, standing and the spread of the book, set out plainly.")
                .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            CounterButton(title: "Read the house rules", weight: .outline) {
                nameFocused = false
                withAnimation(.easeInOut(duration: 0.18)) { showGuide = true }
            }
        }
    }

    // MARK: - Record

    private var recordCard: some View {
        CounterCard {
            CounterSectionTitle(text: "The record so far")
            CounterStatRow(label: "Weeks kept", value: "\(house.week)")
            CounterStatRow(label: "Bargains struck", value: "\(house.book.count)")
            CounterStatRow(label: "Applicants declined", value: "\(house.save.declined)")
            CounterStatRow(label: "Applicants who walked", value: "\(house.save.walkedAway)")
            CounterStatRow(label: "Interest taken", value: Tally.florins(house.save.lifetimeInterest),
                           valueColor: Ink.good)
            CounterStatRow(label: "Coin lost to bad debts", value: Tally.florins(house.save.lifetimeLosses),
                           valueColor: Ink.bad)
            CounterStatRow(label: "Worth of the house now", value: Tally.florins(house.worth), emphasis: true)
        }
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Privacy")
            Text("This game keeps everything on this device. Nothing about your house leaves the phone.")
                .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            CounterButton(title: "Privacy Policy", weight: .outline) {
                nameFocused = false
                showPrivacy = true
            }
        }
    }

    // MARK: - Reset

    private var resetCard: some View {
        CounterCard {
            CounterSectionTitle(text: "Begin again")
            Text(confirmingReset
                 ? "This closes the house and opens a new one. The whole ledger is lost."
                 : "Close this house and start a new campaign with a fresh chest of 2,000 florins.")
                .font(Quill.body(13))
                .foregroundColor(confirmingReset ? Ink.bad : Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            if confirmingReset {
                HStack(spacing: 9) {
                    CounterButton(title: "Yes, close it", weight: .danger) {
                        house.startFresh()
                        draftName = house.houseName
                        confirmingReset = false
                    }
                    CounterButton(title: "Keep the house", weight: .outline) {
                        confirmingReset = false
                    }
                }
            } else {
                CounterButton(title: "Close this house", weight: .outline) {
                    nameFocused = false
                    confirmingReset = true
                }
            }
        }
    }

    private var aboutCard: some View {
        CounterCard(tint: Ink.parchmentDim) {
            Text("Velloro")
                .font(Quill.title(17)).foregroundColor(Ink.burgundy)
            Text("A game about pricing risk in an invented Renaissance city. The cities, houses, trades and people are fiction. Nothing here is advice about money.")
                .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("Version 1.0")
                .font(Quill.label(11)).foregroundColor(Ink.textFaint)
        }
    }
}

/// Wraps the web panel with a way back out. Presented as the app's single sheet.
struct PrivacySheet: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privacy Policy")
                    .font(Quill.heading(16)).foregroundColor(Ink.burgundy)
                Spacer()
                Button(action: dismiss) {
                    Text("Close")
                        .font(Quill.label(12)).foregroundColor(Ink.goldPale)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Ink.burgundy))
                        .contentShape(Rectangle())
                }
                .buttonStyle(FlatPressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Ink.parchmentDim)

            VelloroWebPanel(urlString: VelloroGate.sourceLink)
                .edgesIgnoringSafeArea(.bottom)
        }
        .background(Ink.parchment)
    }
}
