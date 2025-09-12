enum DI {
    static var marketRepo: MarketRepository {
        AppConfig.useMockData ? MockMarketRepository() : LiveMarketRepository()
    }
}
