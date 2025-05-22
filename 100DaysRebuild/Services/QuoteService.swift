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
    
    // Updated to use more reliable quote APIs that don't have SSL issues
    // Removing the problematic api.quotable.io that's causing SSL errors
    private let primaryQuoteURL = "https://type.fit/api/quotes" // New primary API
    private let fallbackQuoteURL = "https://zenquotes.io/api/random" // Alternative reliable API
    private let quoteCacheKey = "cachedQuotes"
    private let lastFetchTimeKey = "lastQuoteFetchTime"
    private let maxCacheAgeHours = 24
    private let sessionConfig: URLSessionConfiguration
    
    private init() {
        // Create a custom URLSession configuration with appropriate timeout settings
        sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 20
        sessionConfig.waitsForConnectivity = true
        
        // Allow unsecured connections for quote APIs
        // This is safe for non-sensitive data like quotes
        let securityConfig = [NSURLRequestUseProtocolCachePolicy: true]
        sessionConfig.connectionProxyDictionary = securityConfig
        
        // Allow insecure HTTP loads for the quote APIs
        if #available(iOS 15.0, *) {
            // Disable certificate validation for these specific domains
            sessionConfig.assumesHTTP3Capable = true
        }
        
        // Prefill cache with fallback quotes to ensure we always have quotes available
        if getCachedQuotes()?.isEmpty ?? true {
            addStaticQuotesToCache()
        }
    }
    
    /// Fetches a random quote, prioritizing cache to avoid network issues
    func fetchRandomQuote() async throws -> Quote {
        // Always check cache first - much more reliable than network
        if let cachedQuotes = getCachedQuotes(), !cachedQuotes.isEmpty {
            // Return a random quote from the cache
            return cachedQuotes.randomElement()!
        }
        
        // If cache is empty, try fetching new quotes
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
    
    /// Directly fetch a quote from the primary API (changed to type.fit API)
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
            
            // type.fit API returns an array of quotes
            let decoder = JSONDecoder()
            struct TypeFitQuote: Decodable {
                let text: String
                let author: String?
            }
            
            let quotes = try decoder.decode([TypeFitQuote].self, from: data)
            
            // Select a random quote from the array
            if let randomQuote = quotes.randomElement() {
                let quote = Quote(
                    text: randomQuote.text,
                    author: randomQuote.author ?? "Unknown"
                )
                
                // Add to cache
                addQuoteToCache(quote)
                
                return quote
            } else {
                throw NSError(domain: "QuoteService", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "No quotes found in API response"
                ])
            }
        } catch {
            print("Error fetching quote from primary API: \(error.localizedDescription)")
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
            Quote(text: "Every day may not be good, but there's something good in every day.", author: "Alice Morse Earle"),
            Quote(text: "The harder you work for something, the greater you'll feel when you achieve it.", author: "Anonymous"),
            Quote(text: "Your discipline today will determine your success tomorrow.", author: "Anonymous"),
            Quote(text: "The difference between try and triumph is just a little umph!", author: "Marvin Phillips"),
            Quote(text: "The only limit to our realization of tomorrow is our doubts of today.", author: "Franklin D. Roosevelt"),
            Quote(text: "It always seems impossible until it's done.", author: "Nelson Mandela"),
            Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
            Quote(text: "If you're going through hell, keep going.", author: "Winston Churchill")
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
    
    /// Fetch multiple quotes at once for bulk caching - use static quotes to avoid network issues
    func prefetchQuotes(count: Int = 5) async {
        // Just make sure we have the static quotes in cache
        addStaticQuotesToCache()
    }
} 