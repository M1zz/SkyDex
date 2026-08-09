import SwiftUI

struct ReferenceDetailView: View {
    let reference: ReferenceSky
    let isReached: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(reference.rgb))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(reference.bandName) · \(reference.skyLabel) 하늘")
                            .font(.headline)
                        Text(reference.hex)
                            .font(.footnote)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text(isReached ? "이 근처의 하늘을 이미 모았어요." : "아직 이 근처의 하늘은 없어요.")
                    .font(.subheadline)

                Text("참고 팔레트는 목표가 아니라 안내입니다. 이 색과 맞지 않아도 새로운 하늘이면 그대로 수집돼요. 계절이 끝날 때까지 여기 닿지 못해도 잃는 것은 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
