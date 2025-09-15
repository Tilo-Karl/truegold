enum DI {
    static var marketRepo: MarketRepository {
        TestPhase.useMockData ? MockMarketRepository() : LiveMarketRepository()
    }
}
