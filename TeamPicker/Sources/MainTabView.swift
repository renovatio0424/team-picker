import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("팀 뽑기", systemImage: "person.3.fill")
                }

            StandupView()
                .tabItem {
                    Label("스탠드업", systemImage: "clock.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
