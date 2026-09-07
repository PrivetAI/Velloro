import SwiftUI

struct VelloroLoadingScreen: View {
    @State private var tilt = false
    @State private var glow = false

    var body: some View {
        ZStack {
            Ink.burgundyDeep.edgesIgnoringSafeArea(.all)

            VStack(spacing: 26) {
                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(Ink.gold.opacity(0.28), lineWidth: 1.5)
                        .frame(width: 148, height: 148)
                        .scaleEffect(glow ? 1.05 : 0.94)
                    BalanceGlyph()
                        .fill(Ink.goldBright)
                        .frame(width: 108, height: 108)
                        .rotationEffect(.degrees(tilt ? 3.5 : -3.5))
                }
                .animation(Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: tilt)
                .animation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glow)

                VStack(spacing: 7) {
                    Text("Velloro")
                        .font(Quill.title(26))
                        .foregroundColor(Ink.goldBright)
                        .multilineTextAlignment(.center)
                    Rectangle()
                        .fill(Ink.gold.opacity(0.6))
                        .frame(width: 108, height: 1)
                    Text("A lending house at the counter")
                        .font(Quill.body(13))
                        .foregroundColor(Ink.goldPale.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 0)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Ink.gold.opacity(glow ? 0.85 : 0.30))
                            .frame(width: 7, height: 7)
                            .animation(Animation.easeInOut(duration: 0.7)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18), value: glow)
                    }
                }
                .padding(.bottom, 46)
            }
        }
        .onAppear {
            tilt = true
            glow = true
        }
    }
}
