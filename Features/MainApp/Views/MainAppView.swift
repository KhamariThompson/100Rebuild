struct MainApp_SocialTabView: View {
    var body: some View {
        NavigationView {
            SocialView()
                .navigationTitle("Social")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
} 