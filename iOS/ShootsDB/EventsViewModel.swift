import Foundation
import Combine

/**
 class EventsViewModel: ObservableObject {
 @Published var events: [ShootEvent] = []
 @Published var filter = ShootFilter()
 @Published var isLoading = false
 
 private var cancellables = Set<AnyCancellable>()
 private let apiService = ShootsAPIService()
 
 init() {
 // Observe filter changes and trigger new search
 $filter
 .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
 .sink { [weak self] _ in
 self?.fetchEvents()
 }
 .store(in: &cancellables)
 }
 
 func fetchEvents(page: Int = 1) {
 isLoading = true
 
 apiService.fetchEvents(filter: filter, page: page)
 .sink(
 receiveCompletion: { [weak self] completion in
 self?.isLoading = false
 if case .failure(let error) = completion {
 print("Error fetching events: \(error)")
 }
 },
 receiveValue: { [weak self] newEvents in
 if page == 1 {
 self?.events = newEvents
 } else {
 self?.events.append(contentsOf: newEvents)
 }
 }
 )
 .store(in: &cancellables)
 }
 
 func resetFilters() {
 filter.reset()
 }
 }
 **/
