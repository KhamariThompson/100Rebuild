import Foundation

// Structure to decode API response
struct QuoteAPIResponse: Decodable {
    let content: String
    let author: String
    let tags: [String]?
}

// Alternative API response structure
struct ZenQuoteAPIResponse: Decodable {
    let q: String
    let a: String
    let h: String?
}

class QuoteService {
    static let shared = QuoteService()
    
    // Updated to use multiple quote API endpoints in case one fails
    private let primaryQuoteURL = "https://api.quotable.io/random?tags=inspirational,motivational,success"
    private let fallbackQuoteURL = "https://zenquotes.io/api/random" // Alternative reliable API
    private let quoteCacheKey = "cachedQuotes"
    private let lastFetchTimeKey = "lastQuoteFetchTime"
    private let maxCacheAgeHours = 24
    private let sessionConfig: URLSessionConfiguration
    
    private init() {
        // Create a custom URLSession configuration with stronger SSL settings
        sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 15
        sessionConfig.timeoutIntervalForResource = 30
        sessionConfig.waitsForConnectivity = true
        
        // Prefill cache with fallback quotes
        if getCachedQuotes()?.isEmpty ?? true {
            addStaticQuotesToCache()
        }
    }
    
    /// Fetches a random quote from the API, with caching to avoid rate limits
    func fetchRandomQuote() async throws -> Quote {
        // Check if we have cached quotes and if the cache is still valid
        if let cachedQuotes = getCachedQuotes(), !cachedQuotes.isEmpty, !shouldRefreshCache() {
            // Return a random quote from the cache
            return cachedQuotes.randomElement()!
        }
        
        // If cache is empty or expired, try fetching new quotes
        do {
            return try await fetchQuoteFromAPI()
        } catch {
            print("Primary quote API failed: \(error.localizedDescription)")
            // Try fallback API if primary fails
            do {
                return try await fetchQuoteFromFallbackAPI()
            } catch let fallbackError {
                print("Fallback quote API also failed: \(fallbackError.localizedDescription)")
                // Return from static fallback quotes if both APIs fail
                return getStaticFallbackQuote()
            }
        }
    }
    
    /// Directly fetch a quote from the primary API
    private func fetchQuoteFromAPI() async throws -> Quote {
        guard let url = URL(string: primaryQuoteURL) else {
            throw NSError(domain: "QuoteService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL"
            ])
        }
        
        // Use the session with custom config
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "QuoteService", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid server response"
                ])
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(QuoteAPIResponse.self, from: data)
            
            let quote = Quote(text: apiResponse.content, author: apiResponse.author)
            
            // Add to cache
            addQuoteToCache(quote)
            
            return quote
        } catch {
            print("Error fetching quote from primary API: \(error.localizedDescription)")
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == -1200 {
                print("SSL certificate validation error - will try fallback API")
            }
            throw error
        }
    }
    
    /// Fetch from fallback API
    private func fetchQuoteFromFallbackAPI() async throws -> Quote {
        guard let url = URL(string: fallbackQuoteURL) else {
            throw NSError(domain: "QuoteService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid fallback URL"
            ])
        }
        
        // Use the session with custom config
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "QuoteService", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid fallback server response"
                ])
            }
            
            let decoder = JSONDecoder()
            
            // The fallback API returns an array with one item
            if let zenQuotes = try? decoder.decode([ZenQuoteAPIResponse].self, from: data),
               let zenQuote = zenQuotes.first {
                let quote = Quote(text: zenQuote.q, author: zenQuote.a)
                
                // Add to cache
                addQuoteToCache(quote)
                
                return quote
            } else {
                throw NSError(domain: "QuoteService", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse fallback API response"
                ])
            }
        } catch {
            print("Error fetching quote from fallback API: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get a static fallback quote when both APIs fail
    private func getStaticFallbackQuote() -> Quote {
        let fallbackQuotes = [
            Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
            Quote(text: "Small daily improvements over time lead to stunning results.", author: "Robin Sharma"),
            Quote(text: "Consistency is the key to achieving and maintaining momentum.", author: "Brian Tracy"),
            Quote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
            Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
            Quote(text: "Don't count the days, make the days count.", author: "Muhammad Ali"),
            Quote(text: "Habits are the compound interest of self-improvement.", author: "James Clear"),
            Quote(text: "Every day may not be good, but there's something good in every day.", author: "Alice Morse Earle")
        ]
        
        return fallbackQuotes.randomElement()!
    }
    
    /// Add static quotes to the cache for first launch or when APIs fail
    private func addStaticQuotesToCache() {
        let fallbackQuotes = [
            Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
            Quote(text: "Small daily improvements over time lead to stunning results.", author: "Robin Sharma"),
            Quote(text: "Consistency is the key to achieving and maintaining momentum.", author: "Brian Tracy"),
            Quote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
            Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
            Quote(text: "Don't count the days, make the days count.", author: "Muhammad Ali"),
            Quote(text: "Habits are the compound interest of self-improvement.", author: "James Clear"),
            Quote(text: "Every day may not be good, but there's something good in every day.", author: "Alice Morse Earle")
        ]
        
        var cachedQuotes = getCachedQuotes() ?? []
        
        // Add all static quotes to cache if they're not already there
        for quote in fallbackQuotes {
            if !cachedQuotes.contains(where: { $0.text == quote.text }) {
                cachedQuotes.append(quote)
            }
        }
        
        // Save the updated cache
        if let encoded = try? JSONEncoder().encode(cachedQuotes) {
            UserDefaults.standard.set(encoded, forKey: quoteCacheKey)
            // Update the timestamp of the last fetch
            UserDefaults.standard.set(Date(), forKey: lastFetchTimeKey)
        }
    }
    
    /// Add a quote to the cache
    private func addQuoteToCache(_ quote: Quote) {
        var cachedQuotes = getCachedQuotes() ?? []
        
        // Check if this quote is already in the cache (avoid duplicates)
        if !cachedQuotes.contains(where: { $0.text == quote.text && $0.author == quote.author }) {
            cachedQuotes.append(quote)
            
            // Limit cache size to 50 quotes
            if cachedQuotes.count > 50 {
                cachedQuotes.removeFirst(cachedQuotes.count - 50)
            }
            
            // Save the updated cache
            if let encoded = try? JSONEncoder().encode(cachedQuotes) {
                UserDefaults.standard.set(encoded, forKey: quoteCacheKey)
                // Update the timestamp of the last fetch
                UserDefaults.standard.set(Date(), forKey: lastFetchTimeKey)
            }
        }
    }
    
    /// Get the cached quotes
    private func getCachedQuotes() -> [Quote]? {
        guard let data = UserDefaults.standard.data(forKey: quoteCacheKey) else {
            return nil
        }
        
        return try? JSONDecoder().decode([Quote].self, from: data)
    }
    
    /// Check if we should refresh the cache based on age
    private func shouldRefreshCache() -> Bool {
        guard let lastFetchDate = UserDefaults.standard.object(forKey: lastFetchTimeKey) as? Date else {
            return true // No previous fetch, should refresh
        }
        
        let hoursSinceLastFetch = Calendar.current.dateComponents([.hour], from: lastFetchDate, to: Date()).hour ?? 0
        
        return hoursSinceLastFetch >= maxCacheAgeHours
    }
    
    /// Fetch multiple quotes at once for bulk caching
    func prefetchQuotes(count: Int = 5) async {
        // Don't prefetch if cache is still valid
        guard shouldRefreshCache() else { return }
        
        // Fetch quotes in parallel
        await withTaskGroup(of: Quote?.self) { group in
            for _ in 0..<count {
                group.addTask {
                    do {
                        return try await self.fetchQuoteFromAPI()
                    } catch {
                        print("Error prefetching quote: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            
            // Process results
            for await quote in group {
                if let quote = quote {
                    addQuoteToCache(quote)
                }
            }
        }
    }
} 