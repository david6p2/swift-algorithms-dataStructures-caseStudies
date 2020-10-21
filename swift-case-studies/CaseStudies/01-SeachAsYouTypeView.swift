import SwiftUI
import Combine
import CombineSchedulers

/*:
 Using Combine Schedulers for testablility
 https://www.pointfree.co/blog/posts/45-open-sourcing-combineschedulers
 */

extension AnyPublisher {
    public init(value: Output) {
        self.init(Just(value).setFailureType(to: Failure.self))
    }
    
    public init(error: Failure) {
        self.init(Fail(error: error))
    }
}

// MARK: Cancellable + AnyPublisher
var cancellationCancellables: [AnyHashable: Set<AnyCancellable>] = [:]
let cancellablesLock = NSRecursiveLock()

extension AnyPublisher {
    public func cancellable(id: AnyHashable) -> Self {
      let publisher = Deferred { () -> AnyPublisher<Output, Failure> in
        cancellablesLock.lock()
        defer { cancellablesLock.unlock() }

        let subject = PassthroughSubject<Output, Failure>()
        let cancellable = self.subscribe(subject)

        var cancellationCancellable: AnyCancellable!
        cancellationCancellable = AnyCancellable {
            cancellablesLock.lock()
            defer { cancellablesLock.unlock() }
            
            subject.send(completion: .finished)
            cancellable.cancel()
            cancellationCancellables[id]?.remove(cancellationCancellable)
            
            if cancellationCancellables[id]?.isEmpty == .some(true) {
              cancellationCancellables[id] = nil
            }
        }

        cancellationCancellables[id, default: []].insert(cancellationCancellable)

        return subject.handleEvents(
          receiveCompletion: { _ in cancellationCancellable.cancel() },
          receiveCancel: cancellationCancellable.cancel
        )
        .eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()

        return .concatenate([.cancel(id: id), publisher])
    }
    
    public static func cancel(id: AnyHashable) -> AnyPublisher {
        Deferred { () -> AnyPublisher<Output, Failure> in
            cancellablesLock.lock()
            defer { cancellablesLock.unlock() }
            
            cancellationCancellables[id]?.forEach { $0.cancel() }
            return Just<Output?>(nil)
                .setFailureType(to: Failure.self)
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    public static func concatenate<C: Collection>(
      _ effects: C
    ) -> AnyPublisher where C.Element == AnyPublisher {
      guard let first = effects.first else { return Empty(completeImmediately: true).eraseToAnyPublisher() }

      return
        effects
        .dropFirst()
        .reduce(into: first) { effects, effect in
            effects = effects.append(effect).eraseToAnyPublisher()
        }
    }
}

struct SearchClient {
    var search: (String) -> AnyPublisher<[String], URLError>
}

extension SearchClient {
    static let echo = Self(
        search: { .init(value: [$0]) }
    )
    
    static let theMovieDb = Self(
        search: {
            TheMovieDb
                .searchMovie(query: $0)
                .map { $0.results.map(\.title) }
                .mapError {
                    ($0 as? URLError) ?? URLError(.networkConnectionLost)
                }
                .eraseToAnyPublisher()
        }
    )
}

class SearchAsYouTypeViewModel: ObservableObject {
    struct CancelId: Hashable {}
    struct Dependencies {
        var searchClient: SearchClient
        var scheduler: AnySchedulerOf<DispatchQueue> =  DispatchQueue.main.eraseToAnyScheduler()
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: Dependencies
    @Published var query: String = ""
    @Published var results: [String] = []
    @Published var isRequestInFlight = false
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        
        $query
            .filter { $0.count >= 3 }
            .setFailureType(to: URLError.self)
            .debounce(
                for: .milliseconds(300),
                scheduler: dependencies.scheduler
            )
            .removeDuplicates()
            .handleEvents(
                receiveOutput: { _ in self.isRequestInFlight = true }
            )
            .flatMap { query -> AnyPublisher<[String], URLError> in
                dependencies.searchClient
                    .search(query)
                    .cancellable(id: CancelId())
            }
            .receive(on: dependencies.scheduler)
            .handleEvents(
                receiveOutput: { _ in self.isRequestInFlight = false }
            )
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { self.results = $0 }
            )
            .store(in: &cancellables)
    }
}

struct SeachAsYouTypeView: View {
    @ObservedObject var viewModel: SearchAsYouTypeViewModel
    
    var body: some View {
        VStack {
            TextField(
                "Search",
                text: $viewModel.query
            )
            .padding()
            
            List {
                if viewModel.isRequestInFlight {
                    ProgressView()
                }
                
                ForEach(viewModel.results, id: \.self) { result in
                    Text(result)
                }
            }
        }
    }
}

struct SeachAsYouTypeView_Previews: PreviewProvider {
    static var previews: some View {
        SeachAsYouTypeView(
            viewModel: .init(
                dependencies: .init(
                    searchClient: .theMovieDb
                )
            )
        )
    }
}
