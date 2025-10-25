struct MainApp_SocialTabView: View {
    var body: some View {
        NavigationView {
            SocialFeedView()
                .navigationTitle("Social")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
} 