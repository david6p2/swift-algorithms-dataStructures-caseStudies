import SwiftUI

class SearchAsYouTypeViewModel: ObservableObject {

  public var porscheModelToSearch: CarModel?
  public var porscheModelsResult: CarModelResult? = nil
  public var carsResults: [CarResult] = []
  var filteredCarsResults: [CarResult] = []

  private var dataLoader: DataLoader
  private var isFetchInProgress = false
  var hasMoreResults = true

  @Published var results: [String] = []
  @Published var query: String = ""

  init() {
    self.dataLoader = DataLoader()
    searchPorscheModel(nil, page: 1) { [weak self] (result) in
      guard let self = self else { return }

      switch result {
      case .success(let carModelsResult):
        self.results.append(contentsOf: (carModelsResult?.results.map{ $0.title })!)
      case . failure(let error):
        print(error)
      }
    }
  }

  func searchPorscheModel(_ model: String?, page: Int = 1, completion: @escaping (Result<CarModelResult?, DCError>) -> Void) {
    guard !isFetchInProgress else {
      return
    }

    isFetchInProgress = true

    dataLoader.searchResultsForCarModel(model, query: self.query, withPage: page) { [weak self] (result) in
      switch result {
      case .success(let carModelsResult):
        self?.isFetchInProgress = false
        if carModelsResult.paging.total < carModelsResult.paging.offset + carModelsResult.paging.limit {
          self?.hasMoreResults = false
        }
        self?.porscheModelsResult = carModelsResult
        self?.carsResults.append(contentsOf: carModelsResult.results)
        print(carModelsResult.results)
        completion(.success(self?.porscheModelsResult))
        break
      case .failure(let error):
        self?.isFetchInProgress = false
        let errorInfo = error.errorInfo ?? DataLoader.noErrorDescription
        //os_log(.debug, log: .carResultsController, "%{public}@", errorInfo)
        completion(.failure(error))
        break
      }
    }
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
        ForEach(viewModel.results, id: \.self) { result in
          Text(result)
        }
      }
    }
  }
}



struct SeachAsYouTypeView_Previews: PreviewProvider {
    static var previews: some View {
      SeachAsYouTypeView(viewModel: SearchAsYouTypeViewModel())
    }
}
