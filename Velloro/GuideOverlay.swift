import SwiftUI

struct GuideOverlay: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Ink.parchment.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                CounterHeader(title: "Velloro",
                              subtitle: "How a lending house is kept")
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 13) {
                        chapter("What you actually do",
                                "You do not tap anything to earn coin, and you do not buy cheap in one place to sell dear in another. You sit at a counter and price risk. Applicants come with a sum in mind. You decide what to charge, for how long, and what you will hold as security — or you send them away.")
                        chapter("Nothing tells you who will pay",
                                "Every applicant carries a handful of remarks: what the guild says, what a rival says, how the ledger looks, whether a ship is overdue. Some of these predict failure very strongly. Some are pure noise dressed up to look meaningful. The weights never change over a campaign, and they are never shown. You learn them from the Signals page of your own ledger, and from nowhere else.")
                        chapter("The rate cuts both ways",
                                "Charge too little and the good business does not pay for the bad. Charge too much and the sound borrowers take their custom elsewhere — leaving you exactly the ones who had no better offer. A hard rate also presses a borrower harder, and a pressed borrower fails more often.")
                        chapter("Pledges",
                                "A pledge is only worth what it fetches at a forced sale. Silver plate sells at once; a strip of land does not. Demanding the tools of a trade offends far more than demanding plate. Until you engage an assayer, the value written down is only what the borrower claims.")
                        chapter("Term and capital",
                                "A long term earns more interest and gives misfortune more time to arrive. A short term brings your coin back sooner, and coin in the chest is coin you can lend to the next good bargain. You cannot lend what you do not hold: over-commit to long loans and you will watch a fine short one walk out of the door.")
                        chapter("When a loan fails",
                                "You choose. Seize the pledges and recover more coin, at the cost of your standing in the city. Compose terms and recover less but be spoken of kindly. Standing decides how many applicants come to the door and how sound they are, so neither choice is free.")
                        chapter("Spread of the book",
                                "A harvest failure, a war levy, a sumptuary law: these strike a whole trade at once. If most of your coin sits in one kind of business, one season can take the lot. The Ledger shows how narrow your book has become, and a narrow book raises the chance of failure on every claim in it.")
                        chapter("Growing",
                                "Clerks read more of what the city knows. An assayer values pledges honestly. A notary recovers more from a forced sale. New counters in other cities bring different trades to the door — the surest cure for a narrow book. Bills of exchange and commenda partnerships open as the house grows, and each one changes what your decision actually is.")
                        CounterCard(tint: Ink.parchmentDim) {
                            Text("A note on the setting")
                                .font(Quill.heading(15)).foregroundColor(Ink.burgundy)
                            Text("Ardenza, Portovaro, Kelsburg and Miralta are invented, as are the houses and the people. The florin here is a game counter and nothing else. Nothing in this app is advice about money.")
                                .font(Quill.body(12.5)).foregroundColor(Ink.textSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CounterButton(title: "Open the counter", weight: .solid) { dismiss() }
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

    private func chapter(_ title: String, _ body: String) -> some View {
        CounterCard {
            Text(title).font(Quill.heading(16)).foregroundColor(Ink.burgundy)
            Text(body)
                .font(Quill.body(13.5)).foregroundColor(Ink.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RuinOverlay: View {
    @ObservedObject var house: HouseLedger
    let readOn: () -> Void

    var body: some View {
        ZStack {
            Ink.parchment.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                CounterHeader(title: "The House is Closed",
                              subtitle: "Week \(house.week)")
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        CounterCard {
                            Text("The chest is empty and nothing is out on loan. The counter shuts and the clerks are paid off.")
                                .font(Quill.body(14.5)).foregroundColor(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CounterCard {
                            CounterSectionTitle(text: "What the book says")
                            CounterStatRow(label: "Weeks kept", value: "\(house.week)")
                            CounterStatRow(label: "Bargains struck", value: "\(house.book.count)")
                            CounterStatRow(label: "Interest taken",
                                           value: Tally.florins(house.save.lifetimeInterest), valueColor: Ink.good)
                            CounterStatRow(label: "Coin lost",
                                           value: Tally.florins(house.save.lifetimeLosses), valueColor: Ink.bad)
                            CounterStatRow(label: "Went bad",
                                           value: Tally.percent(house.overallFailureRate))
                            CounterStatRow(label: "Greatest worth reached",
                                           value: Tally.florins(house.save.peakWorth), emphasis: true)
                        }
                        CounterCard(tint: Ink.parchmentDim) {
                            Text("Before you begin again")
                                .font(Quill.heading(15)).foregroundColor(Ink.burgundy)
                            Text("The Signals page of a ruined ledger is still worth reading. The weights that undid this house are the same ones the next one will face.")
                                .font(Quill.body(13)).foregroundColor(Ink.textSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CounterButton(title: "Read the old ledger first", weight: .outline) { readOn() }
                        CounterButton(title: "Open a new house", weight: .solid) {
                            house.startFresh()
                        }
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
}
