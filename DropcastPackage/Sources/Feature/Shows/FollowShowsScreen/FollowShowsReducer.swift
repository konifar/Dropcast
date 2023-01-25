import ComposableArchitecture
import Entity
import ITunesClient
import MessageClient

public struct FollowShowsReducer: ReducerProtocol, Sendable {
    public struct State: Equatable {
        public enum Shows: Equatable {
            case present(shows: [Show])
            case empty
        }

        public var query: String = ""
        public var shows: Shows = .present(shows: [])
    }

    public enum Action: Equatable {
        case queryChanged(query: String)
        case queryChangeDebounced

        case searchResponse(TaskResult<[Show]>)
    }

    @Dependency(\.iTunesClient) private var iTunesClient
    @Dependency(\.messageClient) private var messageClient

    private enum SearchID {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .queryChanged(let query):
                state.query = query

                if query.isEmpty {
                    state.shows = .present(shows: [])
                    return .cancel(id: SearchID.self)
                } else {
                    return .none
                }
            case .queryChangeDebounced:
                let query = state.query
                guard !query.isEmpty else {
                    return .none
                }

                return .task {
                    await .searchResponse(
                        TaskResult {
                            try await self.iTunesClient.searchShows(query)
                        }
                    )
                }
                .cancellable(id: SearchID.self)
            case .searchResponse(let result):
                switch result {
                case .success(let shows):
                    state.shows = shows.isEmpty ? .empty : .present(shows: shows)
                    return .none
                case .failure(let error):
                    return .fireAndForget {
                        messageClient.presentError(error.userMessage)
                    }
                }
            }
        }
    }
}
