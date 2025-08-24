import Foundation
import Combine

/**
 class ShootsAPIService {
 private let baseURL = URL(string: "https://api.shootsdb.com/events")!
 
 // Fetch events with filtering and pagination
 func fetchEvents(
 filter: ShootFilter,
 page: Int = 1,
 pageSize: Int = 20
 ) -> AnyPublisher<[ShootEvent], Error> {
 var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
 
 // Construct query parameters based on filter
 var queryItems: [URLQueryItem] = [
 URLQueryItem(name: "page", value: String(page)),
 URLQueryItem(name: "pageSize", value: String(pageSize))
 ]
 
 if !filter.types.isEmpty {
 queryItems.append(URLQueryItem(
 name: "types",
 value: filter.types.map { $0.rawValue }.joined(separator: ",")
 ))
 }
 
 if !filter.months.isEmpty {
 queryItems.append(URLQueryItem(
 name: "months",
 value: filter.months.map { String($0) }.joined(separator: ",")
 ))
 }
 
 // Add similar query items for other filter properties...
 
 components?.queryItems = queryItems
 
 guard let url = components?.url else {
 return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
 }
 
 return URLSession.shared.dataTaskPublisher(for: url)
 .map { $0.data }
 .decode(type: [ShootEvent].self, decoder: JSONDecoder())
 .receive(on: DispatchQueue.main)
 .eraseToAnyPublisher()
 }
 }
 */
