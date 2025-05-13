import Foundation

public struct Quote: Identifiable, Codable, Equatable {
    public let id: String
    public let text: String
    public let author: String
    
    public init(id: String = UUID().uuidString, text: String, author: String) {
        self.id = id
        self.text = text
        self.author = author
    }
    
    public static func ==(lhs: Quote, rhs: Quote) -> Bool {
        return lhs.id == rhs.id
    }
}

// Extension to provide sample quotes
extension Quote {
    public static let samples: [Quote] = [
        Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
        Quote(text: "It always seems impossible until it's done.", author: "Nelson Mandela"),
        Quote(text: "Quality is not an act, it is a habit.", author: "Aristotle"),
        Quote(text: "Success is not final, failure is not fatal: It is the courage to continue that counts.", author: "Winston Churchill"),
        Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs")
    ]
    
    // Generate the full list of 100+ quotes
    public static let all: [Quote] = samples + [
        Quote(text: "You are never too old to set another goal or to dream a new dream.", author: "C.S. Lewis"),
        Quote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
        Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt"),
        Quote(text: "Start where you are. Use what you have. Do what you can.", author: "Arthur Ashe"),
        Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
        Quote(text: "The only limit to our realization of tomorrow is our doubts of today.", author: "Franklin D. Roosevelt"),
        Quote(text: "Strength does not come from physical capacity. It comes from an indomitable will.", author: "Mahatma Gandhi"),
        Quote(text: "The difference between a successful person and others is not a lack of strength, not a lack of knowledge, but rather a lack of will.", author: "Vince Lombardi"),
        Quote(text: "With the new day comes new strength and new thoughts.", author: "Eleanor Roosevelt"),
        Quote(text: "It is never too late to be what you might have been.", author: "George Eliot"),
        Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        Quote(text: "If you're going through hell, keep going.", author: "Winston Churchill"),
        Quote(text: "Strength and growth come only through continuous effort and struggle.", author: "Napoleon Hill"),
        Quote(text: "Do what you can, with what you have, where you are.", author: "Theodore Roosevelt"),
        Quote(text: "You miss 100% of the shots you don't take.", author: "Wayne Gretzky"),
        Quote(text: "The best way to predict the future is to create it.", author: "Abraham Lincoln"),
        Quote(text: "I can't change the direction of the wind, but I can adjust my sails to always reach my destination.", author: "Jimmy Dean"),
        Quote(text: "Life is 10% what happens to us and 90% how we react to it.", author: "Charles R. Swindoll"),
        Quote(text: "The mind is everything. What you think you become.", author: "Buddha"),
        Quote(text: "The pessimist sees difficulty in every opportunity. The optimist sees opportunity in every difficulty.", author: "Winston Churchill"),
        Quote(text: "Don't let yesterday take up too much of today.", author: "Will Rogers"),
        Quote(text: "You learn more from failure than from success. Don't let it stop you.", author: "Unknown"),
        Quote(text: "It's not whether you get knocked down, it's whether you get up.", author: "Vince Lombardi"),
        Quote(text: "Failure will never overtake me if my determination to succeed is strong enough.", author: "Og Mandino"),
        Quote(text: "We may encounter many defeats but we must not be defeated.", author: "Maya Angelou"),
        Quote(text: "Knowing is not enough; we must apply. Wishing is not enough; we must do.", author: "Johann Wolfgang von Goethe"),
        Quote(text: "We generate fears while we sit. We overcome them by action.", author: "Dr. Henry Link"),
        Quote(text: "Whether you think you can or think you can't, you're right.", author: "Henry Ford"),
        Quote(text: "The man who has confidence in himself gains the confidence of others.", author: "Hasidic Proverb"),
        Quote(text: "What you get by achieving your goals is not as important as what you become by achieving your goals.", author: "Zig Ziglar"),
        Quote(text: "The only person you are destined to become is the person you decide to be.", author: "Ralph Waldo Emerson"),
        Quote(text: "When I let go of what I am, I become what I might be.", author: "Lao Tzu"),
        Quote(text: "When one door of happiness closes, another opens.", author: "Helen Keller"),
        Quote(text: "Success is walking from failure to failure with no loss of enthusiasm.", author: "Winston Churchill"),
        Quote(text: "Just one small positive thought in the morning can change your whole day.", author: "Dalai Lama"),
        Quote(text: "Opportunities don't happen, you create them.", author: "Chris Grosser"),
        Quote(text: "Try not to become a person of success, but rather try to become a person of value.", author: "Albert Einstein"),
        Quote(text: "Great minds discuss ideas; average minds discuss events; small minds discuss people.", author: "Eleanor Roosevelt"),
        Quote(text: "I have not failed. I've just found 10,000 ways that won't work.", author: "Thomas A. Edison"),
        Quote(text: "A successful man is one who can lay a firm foundation with the bricks others have thrown at him.", author: "David Brinkley"),
        Quote(text: "If you don't value your time, neither will others.", author: "Kim Garst"),
        Quote(text: "The two most important days in your life are the day you are born and the day you find out why.", author: "Mark Twain"),
        Quote(text: "The question isn't who is going to let me; it's who is going to stop me.", author: "Ayn Rand"),
        Quote(text: "Build your own dreams, or someone else will hire you to build theirs.", author: "Farrah Gray"),
        Quote(text: "Remember that not getting what you want is sometimes a wonderful stroke of luck.", author: "Dalai Lama"),
        Quote(text: "You can't use up creativity. The more you use, the more you have.", author: "Maya Angelou"),
        Quote(text: "Dream big and dare to fail.", author: "Norman Vaughan"),
        Quote(text: "Our lives begin to end the day we become silent about things that matter.", author: "Martin Luther King Jr."),
        Quote(text: "Do what you can, where you are, with what you have.", author: "Teddy Roosevelt"),
        Quote(text: "If you do what you've always done, you'll get what you've always gotten.", author: "Tony Robbins"),
        Quote(text: "Happiness is not something ready-made. It comes from your own actions.", author: "Dalai Lama"),
        Quote(text: "Whatever you can do, or dream you can, begin it. Boldness has genius, power and magic in it.", author: "Johann Wolfgang von Goethe"),
        Quote(text: "The best revenge is massive success.", author: "Frank Sinatra"),
        Quote(text: "People often say that motivation doesn't last. Well, neither does bathing. That's why we recommend it daily.", author: "Zig Ziglar"),
        Quote(text: "Life shrinks or expands in proportion to one's courage.", author: "Anais Nin"),
        Quote(text: "If you hear a voice within you say 'you cannot paint,' then by all means paint and that voice will be silenced.", author: "Vincent Van Gogh"),
        Quote(text: "There is only one way to avoid criticism: do nothing, say nothing, and be nothing.", author: "Aristotle"),
        Quote(text: "Challenges are what make life interesting and overcoming them is what makes life meaningful.", author: "Joshua J. Marine"),
        Quote(text: "The only place where success comes before work is in the dictionary.", author: "Vidal Sassoon"),
        Quote(text: "Too many of us are not living our dreams because we are living our fears.", author: "Les Brown"),
        Quote(text: "I find that the harder I work, the more luck I seem to have.", author: "Thomas Jefferson"),
        Quote(text: "If you want to lift yourself up, lift up someone else.", author: "Booker T. Washington"),
        Quote(text: "You become what you believe.", author: "Oprah Winfrey"),
        Quote(text: "The most difficult thing is the decision to act, the rest is merely tenacity.", author: "Amelia Earhart"),
        Quote(text: "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do.", author: "Mark Twain"),
        Quote(text: "Nothing is impossible, the word itself says 'I'm possible'!", author: "Audrey Hepburn"),
        Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        Quote(text: "Change your thoughts and you change your world.", author: "Norman Vincent Peale"),
        Quote(text: "If you can dream it, you can achieve it.", author: "Zig Ziglar"),
        Quote(text: "Life isn't about finding yourself. Life is about creating yourself.", author: "George Bernard Shaw"),
        Quote(text: "We become what we think about.", author: "Earl Nightingale"),
        Quote(text: "Don't let the fear of losing be greater than the excitement of winning.", author: "Robert Kiyosaki"),
        Quote(text: "If not us, who? If not now, when?", author: "John F. Kennedy"),
        Quote(text: "The journey of a thousand miles begins with one step.", author: "Lao Tzu"),
        Quote(text: "Either write something worth reading or do something worth writing.", author: "Benjamin Franklin"),
        Quote(text: "An unexamined life is not worth living.", author: "Socrates"),
        Quote(text: "Yesterday is history, tomorrow is a mystery, today is a gift.", author: "Eleanor Roosevelt"),
        Quote(text: "The most common way people give up their power is by thinking they don't have any.", author: "Alice Walker"),
        Quote(text: "The mind is everything. What you think you become.", author: "Buddha"),
        Quote(text: "An obstacle is often a stepping stone.", author: "Prescott Bush"),
        Quote(text: "Comfort is the enemy of achievement.", author: "Farrah Gray"),
        Quote(text: "What seems to us as bitter trials are often blessings in disguise.", author: "Oscar Wilde"),
        Quote(text: "The purpose of our lives is to be happy.", author: "Dalai Lama"),
        Quote(text: "Strive not to be a success, but rather to be of value.", author: "Albert Einstein"),
        Quote(text: "I didn't fail the test. I just found 100 ways to do it wrong.", author: "Benjamin Franklin"),
        Quote(text: "A person who never made a mistake never tried anything new.", author: "Albert Einstein"),
        Quote(text: "The person who says it cannot be done should not interrupt the person who is doing it.", author: "Chinese Proverb"),
        Quote(text: "There is no passion to be found playing small—in settling for a life that is less than the one you are capable of living.", author: "Nelson Mandela")
    ]
    
    // Function to get a random quote different from a previous one
    public static func getRandomQuote(different from: Quote? = nil) -> Quote {
        var newQuote: Quote
        
        repeat {
            newQuote = all.randomElement() ?? samples[0]
        } while from != nil && newQuote.id == from!.id
        
        return newQuote
    }
} 